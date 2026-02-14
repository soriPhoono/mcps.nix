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

  cfg = config.programs.gemini-cli;

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

in
{
  options.programs.gemini-cli = {
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

    settings = mkOption {
      type = types.attrs;
      default = { };
      description = lib.mdDoc "Configuration for gemini-cli (written to settings.json)";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    programs.gemini-cli.settings = {
      mcpServers = allServerConfigs;
    };

    home.file.".gemini/settings.json".text = builtins.toJSON cfg.settings;

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
