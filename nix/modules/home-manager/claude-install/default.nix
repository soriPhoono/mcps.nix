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

  claudeCfg = config.programs.claude-code;
  cfg = config.programs.claude-code;

  # ----------------------
  # Tools Management
  # ----------------------
  baseTools = import ../../../../tools.nix {
    inherit pkgs lib;
    inputs = { };
  };
  extendedTools = baseTools.extend (cfg.extraTools or { });

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
      enabledPresets = lib.filterAttrs (name: preset: name != "servers" && preset.enable) cfg.mcps;
    in
    lib.mapAttrs (_: preset: preset.mcpServer) enabledPresets;

  allServerConfigs = enabledPresetServers // cfg.mcps.servers;

  # ----------------------
  # MCP Sync Script Generation
  # ----------------------
  mcpSyncScript = pkgs.writeShellScriptBin "mcp-sync" ''
    set -euo pipefail

    CLAUDE_CONFIG="$HOME/.claude.json"

    # Function to get list of configured servers from ~/.claude.json
    get_server_list() {
      if [[ -f "$CLAUDE_CONFIG" ]]; then
        ${pkgs.jq}/bin/jq -r '.mcpServers // {} | keys[]' "$CLAUDE_CONFIG" 2>/dev/null || true
      fi
    }

    echo "Synchronizing MCP servers configuration..."

    # Remove all existing MCP servers
    existing_servers=$(get_server_list)
    if [[ -n "$existing_servers" ]]; then
      echo "Removing existing MCP servers..."
      for server in $existing_servers; do
        ${cfg.package}/bin/claude mcp remove --scope user "$server" > /dev/null 2>&1 || true
      done
    fi

    echo "Installing configured MCP servers..."

    # Install new MCP server configurations
    ${lib.concatStrings (
      lib.mapAttrsToList (name: value: ''
        printf " - Installing ${name} "
        if ${cfg.package}/bin/claude mcp add-json --scope user "${name}" '${builtins.toJSON value}' > /dev/null 2>&1; then
          printf "✅\n"
        fi
      '') allServerConfigs
    )}
    echo "MCP servers synchronization completed!"
  '';

in
{
  options.programs.claude-code.mcps = mkOption {
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

  config = mkIf claudeCfg.enable {

    home.activation.mcpSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${mcpSyncScript}/bin/mcp-sync
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
