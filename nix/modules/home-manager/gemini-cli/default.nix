{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkOption
    mkIf
    types
    ;

  geminiCfg = config.programs.gemini;

  # ----------------------
  # Tools Management
  # ----------------------
  baseTools = import ../../../../tools.nix {
    inherit pkgs lib;
    inputs = { };
  };
  extendedTools = baseTools.extend (geminiCfg.extraTools or { });

  # ----------------------
  # Preset Management
  # ----------------------
  mcpServerOptionsType = import ../../../lib/mcp-server-options.nix lib;
  presetDefinitions = import ../../../../presets.nix {
    inherit config lib pkgs;
    tools = extendedTools;
  };

  presetOptionTypes = lib.mapAttrs (
    name: preset:
    mkOption {
      type = lib.types.submodule preset;
      default = { };
      description = lib.mdDoc (preset.meta.description or "MCP preset for ${name}");
    }
  ) presetDefinitions;

  # ----------------------
  # Server Configuration Management
  # ----------------------
  enabledPresetServers =
    let
      enabledPresets = lib.filterAttrs (name: preset: name != "servers" && preset.enable) geminiCfg.mcps;
    in
    lib.mapAttrs (_: preset: preset.mcpServer) enabledPresets;

  allServerConfigs = enabledPresetServers // geminiCfg.mcps.servers;

  # ----------------------
  # MCP Sync Script Generation
  # ----------------------
  # Generate the desired MCP servers JSON at build time
  allServerConfigsJson = builtins.toJSON { mcpServers = allServerConfigs; };

  mcpSyncScript = pkgs.writeShellScriptBin "gemini-mcp-sync" ''
    set -euo pipefail

    GEMINI_CONFIG_DIR="$HOME/.gemini"
    GEMINI_CONFIG="$GEMINI_CONFIG_DIR/settings.json"
    JQ="${pkgs.jq}/bin/jq"

    echo "Synchronizing Gemini MCP servers configuration..."

    if [[ ! -d "$GEMINI_CONFIG_DIR" ]]; then
      mkdir -p "$GEMINI_CONFIG_DIR"
    fi

    # Ensure config file exists with valid JSON
    if [[ ! -f "$GEMINI_CONFIG" ]]; then
      echo "{}" > "$GEMINI_CONFIG"
    fi

    # Validate existing config is valid JSON, reset if not
    if ! $JQ empty "$GEMINI_CONFIG" 2>/dev/null; then
      echo "Warning: Invalid JSON in $GEMINI_CONFIG, resetting..."
      echo "{}" > "$GEMINI_CONFIG"
    fi

    # Read the desired MCP servers configuration (generated at build time)
    DESIRED_CONFIG='${allServerConfigsJson}'

    # Update the config file: merge the generated mcpServers into the existing config
    # This might overwrite existing mcpServers config, which is intended behavior for managed config
    UPDATED_CONFIG=$($JQ --argjson desired "$DESIRED_CONFIG" '. * $desired' "$GEMINI_CONFIG")

    # Write back atomically
    echo "$UPDATED_CONFIG" > "$GEMINI_CONFIG.tmp"
    mv "$GEMINI_CONFIG.tmp" "$GEMINI_CONFIG"

    # List installed servers
    echo "Installed MCP servers:"
    echo "$DESIRED_CONFIG" | $JQ -r '.mcpServers | keys[]' | while read -r server; do
      echo " - $server"
    done

    echo "Gemini MCP servers synchronization completed!"
  '';

in
{
  options.programs.gemini = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Enable gemini integration";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.gemini-cli;
      defaultText = lib.literalExpression "pkgs.gemini-cli";
      description = lib.mdDoc "The gemini-cli package to install.";
    };

    extraTools = mkOption {
      type = types.attrs;
      default = { };
      description = lib.mdDoc "Extra tools to make available to the MCP presets";
    };

    mcps = mkOption {
      type = types.submodule {
        imports = [
          (
            (
              { config, ... }:
              {
                options = presetOptionTypes // {
                  servers = mkOption {
                    type = types.attrsOf (types.submodule mcpServerOptionsType);
                    default = { };
                    description = lib.mdDoc "Custom MCP server configurations";
                  };
                };
              }
            )
          )
        ];
      };
      default = { };
      description = lib.mdDoc "MCP server configurations";
    };

    mcpServers = mkOption {
      type = types.attrsOf (types.submodule mcpServerOptionsType);
      internal = true;
      default = { };
      description = lib.mdDoc "Computed MCP servers configuration (internal)";
    };
  };

  config = mkIf geminiCfg.enable {
    home.packages = [ geminiCfg.package ];

    home.activation.geminiMcpSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${mcpSyncScript}/bin/gemini-mcp-sync
    '';

    programs.gemini.mcpServers = allServerConfigs;

    assertions = lib.flatten (
      lib.mapAttrsToList (name: serverCfg: [
        {
          assertion = (serverCfg.type != "stdio") || (serverCfg.command != "");
          message = "Command must be specified when type is 'stdio' for MCP server '${name}'";
        }
        {
          assertion = (serverCfg.type != "sse") || (serverCfg.url != "");
          message = "URL must be specified when type is 'sse' for MCP server '${name}'";
        }
      ]) allServerConfigs
    );
  };
}
