{
  config,
  lib,
  pkgs,
  inputs ? {},
  ...
}: let
  inherit
    (lib)
    mkOption
    mkIf
    types
    ;

  cfg = config.programs.antigravity;

  # ----------------------
  # Construct inputs for tools.nix.
  # ----------------------
  toolsInputs =
    inputs
    // (
      if inputs ? mcps
      then inputs.mcps.inputs
      else {}
    );

  baseTools = import ../../../../tools.nix {
    inherit pkgs lib;
    inputs = toolsInputs;
  };

  # ----------------------
  # Preset Management
  # ----------------------
  mcpServerOptionsType = import ../../../lib/mcp-server-options.nix lib;
  presetDefinitions = import ../../../../presets.nix {
    inherit config lib pkgs;
    tools = baseTools;
  };

  presetOptionTypes =
    lib.mapAttrs (
      name: preset:
        mkOption {
          type = lib.types.submodule preset;
          default = {};
          description = lib.mdDoc (preset.meta.description or "MCP preset for ${name}");
        }
    )
    presetDefinitions;

  # ----------------------
  # Server Configuration Management
  # ----------------------
  enabledPresetServers = let
    enabledPresets = lib.filterAttrs (name: preset: name != "servers" && preset.enable) cfg.mcps;
  in
    lib.mapAttrs (_: preset: preset.mcpServer) enabledPresets;

  allServerConfigs = enabledPresetServers // cfg.mcps.servers;

  # ----------------------
  # MCP Sync Script Generation
  # ----------------------
  allServerConfigsJson = builtins.toJSON allServerConfigs;
  desiredServersFile = pkgs.writeText "antigravity-desired-servers.json" allServerConfigsJson;

  mcpSyncScript = pkgs.writeShellScriptBin "antigravity-mcp-sync" ''
    set -euo pipefail

    ANTIGRAVITY_CONFIG_DIR="$HOME/.gemini/antigravity"
    ANTIGRAVITY_CONFIG="$ANTIGRAVITY_CONFIG_DIR/mcp_config.json"
    JQ="${pkgs.jq}/bin/jq"

    echo "Synchronizing Antigravity MCP servers configuration..."

    # Ensure config directory exists
    mkdir -p "$ANTIGRAVITY_CONFIG_DIR"

    # Ensure config file exists with valid JSON
    if [[ ! -f "$ANTIGRAVITY_CONFIG" ]]; then
      echo "{}" > "$ANTIGRAVITY_CONFIG"
    fi

    # Validate existing config is valid JSON, reset if not
    if ! $JQ empty "$ANTIGRAVITY_CONFIG" 2>/dev/null; then
       echo "Warning: Invalid JSON in $ANTIGRAVITY_CONFIG, resetting..."
       echo "{}" > "$ANTIGRAVITY_CONFIG"
    fi

    # Update the config file: replace mcpServers entirely with desired config
    UPDATED_CONFIG=$($JQ --slurpfile servers "${desiredServersFile}" '.mcpServers = $servers[0]' "$ANTIGRAVITY_CONFIG")

    # Write back atomically
    echo "$UPDATED_CONFIG" > "$ANTIGRAVITY_CONFIG.tmp"
    mv "$ANTIGRAVITY_CONFIG.tmp" "$ANTIGRAVITY_CONFIG"

    # List installed servers
    echo "Installed Antigravity MCP servers:"
    $JQ -r 'keys[]' "${desiredServersFile}" | while read -r server; do
      echo " - $server"
    done

    echo "Antigravity MCP servers synchronization completed!"
  '';
in {
  options.programs.antigravity = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Enable antigravity editor agent configuration";
    };

    allowImpermanence = mkOption {
      type = types.bool;
      default = true;
      description = lib.mdDoc "Whether to manage Antigravity settings via an activation script (useful for impermanent systems)";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.antigravity;
      description = lib.mdDoc "The antigravity package to use.";
    };

    mcps = mkOption {
      type = types.submodule {
        imports = [
          (
            _: {
              options =
                presetOptionTypes
                // {
                  servers = mkOption {
                    type = types.attrsOf (types.submodule mcpServerOptionsType);
                    default = {};
                    description = lib.mdDoc "Custom MCP server configurations";
                  };
                };
            }
          )
        ];
      };
      default = {};
      description = lib.mdDoc "MCP server configurations";
    };
  };

  config = mkIf cfg.enable {
    # Antigravity uses VS Code settings under the hood.
    programs.vscode = {
      enable = true;
      inherit (cfg) package;
    };

    home.activation.antigravityMcpSync = mkIf cfg.allowImpermanence (lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ${mcpSyncScript}/bin/antigravity-mcp-sync
    '');
  };
}
