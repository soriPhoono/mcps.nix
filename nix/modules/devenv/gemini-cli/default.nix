{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.gemini.cli;

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
    lib.mkOption {
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
  allServerConfigsJson = builtins.toJSON { mcpServers = allServerConfigs; };

in
{
  options.gemini.cli = {
    enable = lib.mkEnableOption "gemini-cli";

    extraTools = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = lib.mdDoc "Extra tools to make available to the MCP presets";
    };

    mcps = lib.mkOption {
      type = lib.types.submodule {
        imports = [
          (
            (
              { config, ... }:
              {
                options = presetOptionTypes // {
                  servers = lib.mkOption {
                    type = lib.types.attrsOf (lib.types.submodule mcpServerOptionsType);
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
  };

  config = lib.mkIf cfg.enable {
    packages = [ pkgs.gemini-cli ];

    enterShell = ''
      # Generate .gemini/settings.json
      if [ ! -d .gemini ]; then
        mkdir .gemini
      fi
      
      GEMINI_CONFIG=".gemini/settings.json"
      
      # Use jq to update the config, creating it if missing
      if [ ! -f "$GEMINI_CONFIG" ]; then
        echo "{}" > "$GEMINI_CONFIG"
      fi
      
      # Validate existing config
      if ! ${pkgs.jq}/bin/jq empty "$GEMINI_CONFIG" 2>/dev/null; then
         echo "{}" > "$GEMINI_CONFIG"
      fi

      # Update settings
      ${pkgs.jq}/bin/jq --argjson desired '${allServerConfigsJson}' '. * $desired' "$GEMINI_CONFIG" > "$GEMINI_CONFIG.tmp" && mv "$GEMINI_CONFIG.tmp" "$GEMINI_CONFIG"
      
      echo "Configured gemini-cli MCP servers in .gemini/settings.json"
    '';
  };
}
