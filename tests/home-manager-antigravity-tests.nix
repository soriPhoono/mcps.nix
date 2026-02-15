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

        echo "Activation script correctly contains antigravity-mcp-sync"
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
