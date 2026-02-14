{
  inputs,
  pkgs,
  system,
  ...
}:

let
  apiKeyFilepath = "file.token";
  config = inputs.devenv.lib.mkConfig {
    inherit inputs;
    pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [
        inputs.self.overlays.flake
      ];
    };
    modules = [
      inputs.self.devenvModules.gemini-cli
      {
        gemini.cli = {
          enable = true;
          mcps.buildkite = {
            enable = true;
            inherit apiKeyFilepath;
          };
        };
      }
    ];
  };
in
{
  tests = [
    {
      name = "command";
      type = "script";
      script = ''
        CMD_EXPECTED="${config.gemini.cli.mcpServers.buildkite.command}"
        if [[ -z "$CMD_EXPECTED" ]]; then
           echo "gemini-cli does not have mcp server configured"
           exit 1
        fi 
      '';
    }
    {
      name = "environment vars";
      type = "unit";
      expected = {
        "BUILDKITE_API_TOKEN_FILEPATH" = apiKeyFilepath;
      };
      actual = config.gemini.cli.mcpServers.buildkite.env;
    }
    {
      name = "args";
      type = "unit";
      expected = [ "stdio" ];
      actual = config.gemini.cli.mcpServers.buildkite.args;
    }
  ];
}
