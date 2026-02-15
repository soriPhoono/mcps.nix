{
  inputs,
  pkgs,
  system,
  ...
}: let
  # Mock home-manager configuration helper
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
        ../nix/modules/home-manager/antigravity/default.nix
        {
          home = {
            stateVersion = "25.11";
            username = "jdoe";
            homeDirectory = "/test";
          };
          programs.antigravity = {
            enable = true;
            inherit allowImpermanence;
            mcps.git.enable = true;
          };
          # Need this because antigravity module imports programs.vscode
          programs.vscode.enable = true;
        }
      ];
    };

  resultEnabled = mkResult true;
  resultDisabled = mkResult false;
in {
  tests = [
    {
      name = "impermanence-enabled";
      type = "script";
      script = ''
        ${(inputs.nixtest.lib {inherit pkgs;}).helpers.scriptHelpers}

        # Check if the activation script is generated
        ACTIVATION_SCRIPT="${resultEnabled.activationPackage}/activate"

        if ! grep -q "antigravity-mcp-sync" "$ACTIVATION_SCRIPT"; then
           echo "Activation script does not contain antigravity-mcp-sync when enabled"
           exit 1
        fi

        # Extract the path to the sync script
        SYNC_SCRIPT_PATH=$(grep -o '/nix/store/[^"]*-antigravity-mcp-sync/bin/antigravity-mcp-sync' "$ACTIVATION_SCRIPT" | head -n1)

        if [ -z "$SYNC_SCRIPT_PATH" ]; then
           echo "Could not find antigravity-mcp-sync path in activation script"
           exit 1
        fi

        if ! grep -q "antigravity-desired-servers.json" "$SYNC_SCRIPT_PATH"; then
           echo "Sync script does not reference external JSON file (antigravity-desired-servers.json)"
           echo "Content of $SYNC_SCRIPT_PATH:"
           cat "$SYNC_SCRIPT_PATH"
           exit 1
        fi

        if ! grep -q "mcp_config.json" "$SYNC_SCRIPT_PATH"; then
           echo "Sync script does not reference the correct config file (mcp_config.json)"
           echo "Content of $SYNC_SCRIPT_PATH:"
           cat "$SYNC_SCRIPT_PATH"
           exit 1
        fi

        echo "Activation script correctly contains antigravity-mcp-sync, uses external JSON file and correct config path"
      '';
    }
    {
      name = "impermanence-disabled";
      type = "script";
      script = ''
        ${(inputs.nixtest.lib {inherit pkgs;}).helpers.scriptHelpers}

        # Check if the activation script is generated
        ACTIVATION_SCRIPT="${resultDisabled.activationPackage}/activate"

        if grep -q "antigravity-mcp-sync" "$ACTIVATION_SCRIPT"; then
           echo "Activation script contains antigravity-mcp-sync when disabled"
           exit 1
        fi

        echo "Activation script correctly omits antigravity-mcp-sync"
      '';
    }
  ];
}
