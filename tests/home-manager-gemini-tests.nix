{
  inputs,
  pkgs,
  system,
  ...
}: let
  apiKeyFilepath = "file.token";

  # Helper to generate a test configuration
  mkResult = allowImpermanence:
    inputs.home-manager-unstable.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          inputs.self.overlays.flake
        ];
      };
      modules = [
        inputs.self.homeManagerModules.gemini-cli
        {
          disabledModules = ["programs/gemini-cli.nix"];
          home = {
            stateVersion = "25.11";
            username = "jdoe";
            homeDirectory = "/test";
          };
          programs.gemini-cli = {
            enable = true;
            inherit allowImpermanence;
            mcps = {
              buildkite = {
                enable = true;
                inherit apiKeyFilepath;
              };
              git.enable = true;
              filesystem = {
                enable = true;
                allowedPaths = ["/tmp"];
              };
            };
          };
        }
      ];
    };

  resultDeclarative = mkResult false;
  resultImperative = mkResult true;
in {
  tests = [
    # ---------------------------------------------------------
    # Declarative Configuration Tests (allowImpermanence = false)
    # ---------------------------------------------------------
    {
      name = "declarative-command-check";
      type = "script";
      script = ''
        ${(inputs.nixtest.lib {inherit pkgs;}).helpers.scriptHelpers}
        # We can verify the JSON content generated in the files.
        CONFIG_JSON="${resultDeclarative.config.home.file.".gemini/settings.json".text}"

        # Check buildkite
        CMD_BUILDKITE=$(echo "$CONFIG_JSON" | ${pkgs.jq}/bin/jq -r '.mcpServers.buildkite.command')
        if [[ -z "$CMD_BUILDKITE" || "$CMD_BUILDKITE" == "null" ]]; then
           echo "gemini buildkite mcp server not configured"
           exit 1
        fi

        # Check git
        CMD_GIT=$(echo "$CONFIG_JSON" | ${pkgs.jq}/bin/jq -r '.mcpServers.git.command')
        if [[ -z "$CMD_GIT" || "$CMD_GIT" == "null" ]]; then
           echo "gemini git mcp server not configured"
           exit 1
        fi

        # Check filesystem
        CMD_FS=$(echo "$CONFIG_JSON" | ${pkgs.jq}/bin/jq -r '.mcpServers.filesystem.command')
        if [[ -z "$CMD_FS" || "$CMD_FS" == "null" ]]; then
           echo "gemini filesystem mcp server not configured"
           exit 1
        fi

        # Check filesystem args
        FS_ARGS=$(echo "$CONFIG_JSON" | ${pkgs.jq}/bin/jq -r '.mcpServers.filesystem.args[0]')
        if [[ "$FS_ARGS" != "/tmp" ]]; then
           echo "gemini filesystem mcp server args incorrect: $FS_ARGS"
           exit 1
        fi
      '';
    }
    {
      name = "declarative-environment-vars";
      type = "unit";
      expected = {
        "BUILDKITE_API_TOKEN_FILEPATH" = apiKeyFilepath;
      };
      actual = resultDeclarative.config.programs.gemini-cli.settings.mcpServers.buildkite.env;
    }
    {
      name = "declarative-args";
      type = "unit";
      expected = ["stdio"];
      actual = resultDeclarative.config.programs.gemini-cli.settings.mcpServers.buildkite.args;
    }

    # ---------------------------------------------------------
    # Imperative Configuration Tests (allowImpermanence = true)
    # ---------------------------------------------------------
    {
      name = "imperative-activation-script-check";
      type = "script";
      script = ''
        ${(inputs.nixtest.lib {inherit pkgs;}).helpers.scriptHelpers}

        # Check if the activation script is generated
        ACTIVATION_SCRIPT="${resultImperative.activationPackage}/activate"

        if ! grep -q "gemini-mcp-sync" "$ACTIVATION_SCRIPT"; then
           echo "Activation script does not contain gemini-mcp-sync"
           exit 1
        fi

        echo "Activation script contains gemini-mcp-sync"
      '';
    }
    {
      name = "imperative-settings-file-absent";
      type = "unit";
      expected = false;
      # When allowImpermanence is true, we should NOT generate the static settings file
      actual = resultImperative.config.home.file ? ".gemini/settings.json";
    }
  ];
}
