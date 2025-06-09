{ lib, writeShellScript, symlinkJoin, makeBinaryWrapper }:

let
  # wrapWithCredentialFiles: Creates a wrapper for each binary in a derivation that
  # reads credentials from files and injects them as environment variables.
  #
  # Example usage:
  #
  # wrapWithCredentialFiles {
  #   package = pkgs.my-program;
  #   credentialEnvs = [ "API_KEY" "AUTH_TOKEN" ];
  # }
  #
  # You can then use it like:
  #  my-program
  # or with credentials from files:
  #  API_KEY_FILEPATH=/path/to/api-key AUTH_TOKEN_FILEPATH=/path/to/token my-program
  wrapWithCredentialFiles = { package, credentialEnvs, extraEnv ? {}, name ? "${package.name}-with-creds" }:
    let
      # Generate the wrapper script for a binary
      generateWrapper = binary:
        writeShellScript "${binary}-credential-wrapper" ''
          # Function to safely read a file and strip trailing newlines
          read_cred_file() {
            if [[ -r "$1" ]]; then
              # Read file content and remove trailing newline
              content=$(cat "$1" | tr -d '\r' | tr -d '\n')
              echo "$content"
            else
              echo "Warning: Cannot read credential file: $1" >&2
              echo ""
            fi
          }
          
          ${lib.concatMapStringsSep "\n" (env: ''
            # If filepath variable is set, read the file and set the actual env var
            if [[ -n "''${${env}_FILEPATH+x}" ]]; then
              export ${env}="$(read_cred_file "''${${env}_FILEPATH}")"
            fi
          '') credentialEnvs}
          
          # Execute the original binary with all arguments
          exec "${package}/bin/${binary}" "$@"
        '';

      # Find all binaries in the package
      binaries = if package ? meta.mainProgram && package.meta.mainProgram != null
                 then [ package.meta.mainProgram ] 
                 else builtins.attrNames (builtins.readDir "${package}/bin");
      
      # Create wrappers for each binary
      wrappers = lib.listToAttrs (map (binary: {
        name = binary;
        value = {
          original = "${package}/bin/${binary}";
          wrapped = generateWrapper binary;
        };
      }) binaries);

    in symlinkJoin {
      inherit name;
      paths = [ package ];
      
      # Create the bin directory with wrappers
      postBuild = ''
    # First, save everything else (all directories except bin)
    # by moving them to a temporary location
    mkdir -p $TMPDIR/saved
    
    # Find all directories at the root level that are not 'bin'
    for item in $out/*; do
      if [ -d "$item" ] && [ "$(basename "$item")" != "bin" ]; then
        mv "$item" "$TMPDIR/saved/"
      elif [ -f "$item" ]; then
        # Also save top-level files
        mkdir -p "$TMPDIR/saved/top_level_files"
        mv "$item" "$TMPDIR/saved/top_level_files/"
      fi
    done
    
    # Now remove everything and start fresh
    rm -rf $out/*
    
    # Restore all the saved directories
    if [ -d "$TMPDIR/saved" ]; then
      find "$TMPDIR/saved" -mindepth 1 -maxdepth 1 -not -name "top_level_files" -exec mv {} $out/ \;
      
      # Restore top-level files
      if [ -d "$TMPDIR/saved/top_level_files" ]; then
        find "$TMPDIR/saved/top_level_files" -mindepth 1 -maxdepth 1 -exec mv {} $out/ \;
      fi
    fi
    
    # Create the bin directory with our wrappers
    mkdir -p $out/bin
    
    # Link all wrapped binaries
    ${lib.concatMapStringsSep "\n" (binary: ''
      ln -s ${wrappers.${binary}.wrapped} $out/bin/${binary}
    '') binaries}
    
    # Handle any other environment variables we want to permanently set
    ${lib.optionalString (extraEnv != {}) (
      lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: ''
        # Use makeBinaryWrapper to add permanent env vars
        for bin in $out/bin/*; do
          if [ -x "$bin" ]; then
            wrapProgram "$bin" --set ${name} "${value}"
          fi
        done
      '') extraEnv)
    )}
  '';

      # Ensure makeBinaryWrapper is available if we use extraEnv
      nativeBuildInputs = lib.optional (extraEnv != {}) makeBinaryWrapper;
      
      # Preserve metadata from original package
      inherit (package) meta;
      
      # For reference/debugging: keep track of what environment vars we're wrapping
      passthru = {
        inherit credentialEnvs wrappers package;
        unwrapped = package;
      };
    };
in
wrapWithCredentialFiles
