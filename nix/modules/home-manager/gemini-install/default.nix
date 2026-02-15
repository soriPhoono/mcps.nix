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

  geminiCfg = config.programs.gemini-cli;

  # ----------------------
  # Tools Management
  # ----------------------
  baseTools = import ../../../../tools.nix {
    inherit pkgs lib;
    inputs = { };
  };
  # gemini-cli doesn't have extraTools option in standard module yet, but we can support it if we want functionality parity
  # For now, sticking to baseTools as gemini-cli/default.nix does.
  extendedTools = baseTools; 

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
  # We check config.programs.gemini-cli.mcps (defined below)
  cfgMcps = config.programs.gemini-cli.mcps;

  enabledPresetServers =
    let
      enabledPresets = lib.filterAttrs (name: preset: name != "servers" && preset.enable) cfgMcps;
    in
    lib.mapAttrs (_: preset: preset.mcpServer) enabledPresets;

  allServerConfigs = enabledPresetServers // cfgMcps.servers;

  # ----------------------
  # MCP Sync Script Generation
  # ----------------------
  # Generate the desired MCP servers JSON at build time
  allServerConfigsJson = builtins.toJSON allServerConfigs;

  mcpSyncScript = pkgs.writeShellScriptBin "gemini-mcp-sync" ''
    set -euo pipefail

    GEMINI_CONFIG_DIR="$HOME/.gemini"
    GEMINI_CONFIG="$GEMINI_CONFIG_DIR/settings.json"
    JQ="${pkgs.jq}/bin/jq"

    echo "Synchronizing Gemini MCP servers configuration..."

    # Ensure config directory exists
    mkdir -p "$GEMINI_CONFIG_DIR"

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
    DESIRED_SERVERS='${allServerConfigsJson}'

    # Update the config file: replace mcpServers entirely with desired config
    # We use --argjson to safely pass the JSON content
    UPDATED_CONFIG=$($JQ --argjson servers "$DESIRED_SERVERS" '.mcpServers = $servers' "$GEMINI_CONFIG")

    # Write back atomically
    echo "$UPDATED_CONFIG" > "$GEMINI_CONFIG.tmp"
    mv "$GEMINI_CONFIG.tmp" "$GEMINI_CONFIG"

    # List installed servers
    echo "Installed Gemini MCP servers:"
    echo "$DESIRED_SERVERS" | $JQ -r 'keys[]' | while read -r server; do
      echo " - $server"
    done

    echo "Gemini MCP servers synchronization completed!"
  '';

in
{
  options.programs.gemini-cli.mcps = mkOption {
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
    description = lib.mdDoc "MCP server configurations for Gemini";
  };

  config = mkIf geminiCfg.enable {

    home.activation.geminiMcpSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${mcpSyncScript}/bin/gemini-mcp-sync
    '';

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
