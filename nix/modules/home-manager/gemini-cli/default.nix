{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkOption
    mkIf
    types
    ;

  cfg = config.programs.gemini-cli;

  # ----------------------
  # Tools Management
  # ----------------------
  baseTools = import ../../../../tools.nix {
    inherit pkgs lib;
    inputs = {};
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
in {
  options.programs.gemini-cli.mcps = mkOption {
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

  config = mkIf cfg.enable {
    programs.gemini-cli.settings = {
      mcpServers = allServerConfigs;
    };

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
      ])
      allServerConfigs
    );
  };
}
