{
  inputs,
  pkgs,
  system,
  ...
}:

let
  apiKeyFilepath = "file.token";
  
  # Mock home-manager configuration that uses gemini-install
  result = inputs.home-manager-unstable.lib.homeManagerConfiguration {
    pkgs = import inputs.nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        inputs.self.overlays.flake
      ];
    };
    modules = [
      ../nix/modules/home-manager/gemini-install/default.nix # Importing directly to be safe for now
      
      {
        home.stateVersion = "25.11";
        home.username = "jdoe";
        home.homeDirectory = "/test";
        programs.gemini-cli = {
          enable = true;
          mcps.buildkite = {
            enable = true;
            inherit apiKeyFilepath;
          };
          mcps.git.enable = true;
        };
      }
    ];
  };
in
{
  tests = [
    {
      name = "activation-script-generation";
      type = "script";
      script = ''
        ${(inputs.nixtest.lib { inherit pkgs; }).helpers.scriptHelpers}
        
        # Check if the activation script is generated
        ACTIVATION_SCRIPT="${result.activationPackage}/activate"
        
        if ! grep -q "gemini-mcp-sync" "$ACTIVATION_SCRIPT"; then
           echo "Activation script does not contain gemini-mcp-sync"
           exit 1
        fi
        
        echo "Activation script contains gemini-mcp-sync"
      '';
    }
  ];
}
