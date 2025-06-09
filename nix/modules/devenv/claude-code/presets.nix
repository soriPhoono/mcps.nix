{ lib, tools, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf types;
  mcpServerOptionsType = import ./mcp-server-options.nix lib;

  # Helper to transform a simple preset definition into a full module
  mkPresetModule = { name, description ? "MCP integration for ${name}", options ? {}, env ? (_: {}), command, args ? (_: []) }: 
    { config, ... }: {
      options = {
        enable = mkEnableOption description;

        timeoutMillis = mkOption {
          type = types.nullOr types.int;
          default = 5000;
          description = lib.mdDoc "Timeout in milliseconds";
        };

        mcpServer = lib.mkOption {
          type = lib.types.submodule mcpServerOptionsType;
          default = {};
          description = lib.mdDoc "MCP server configuration";
        };
      } // options;

      config = mkIf config.enable {
        mcpServer = {
          type = "stdio";
          inherit command;
          inherit (config) timeoutMillis;
          args = args config;
          env = env config;
        };
      };
    };

  # Simple preset definitions
  presets = {

    asana = {
      name = "Asana";
      command = tools.getToolPath "asana";
      env = config: {
        ASANA_ACCESS_TOKEN_FILEPATH = config.tokenFilepath;
      };
      options = {
        tokenFilepath = mkOption {
          type = types.str;
          description = lib.mdDoc "File containing Asana API access token";
          example = "/var/run/agenix/asana.token";
        };
      };
    };

    github = {
      name = "GitHub";
      command = tools.getToolPath "github";
      args = config: [ "stdio" "--toolsets" (builtins.concatStringsSep "," config.toolsets) ];
      env = config: {
        GITHUB_PERSONAL_ACCESS_TOKEN_FILEPATH = config.tokenFilepath;
      } // (lib.optionalAttrs (config.baseURL != null && config.baseURL != "") {
        GITHUB_HOST = config.baseURL;
      });
      options = {
        tokenFilepath = mkOption {
          type = types.str;
          description = lib.mdDoc "File containing GitHub API access token";
          example = "/var/run/agenix/gh-personal-access.token";
        };

        baseURL = mkOption {
          type = types.nullOr types.str;
          description = lib.mdDoc "Use it for GitHub Enterprise Cloud installs";
          example = "https://<your GHES or ghe.com domain name>";
        };

        toolsets = mkOption {
          type = types.listOf (types.enum [
            "repos" "issues" "users" "pull_requests" "code_security"
          ]);
          default = ["repos" "pull_requests" "users"];
          description = lib.mdDoc "List of GitHub toolsets to enable";
        };
      };
    };

  };

in
  lib.mapAttrs (_: mkPresetModule) presets
