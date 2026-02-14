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
          mcps.git.enable = true;
          mcps.filesystem = {
            enable = true;
            allowedPaths = [ "/tmp" ];
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
        # Check buildkite
        CMD_BUILDKITE="${config.gemini.cli.mcpServers.buildkite.command}"
        if [[ -z "$CMD_BUILDKITE" ]]; then
           echo "gemini-cli buildkite mcp server not configured"
           exit 1
        fi 

        # Check git
        CMD_GIT="${config.gemini.cli.mcpServers.git.command}"
        if [[ -z "$CMD_GIT" ]]; then
           echo "gemini-cli git mcp server not configured"
           exit 1
        fi

        # Check filesystem
        CMD_FS="${config.gemini.cli.mcpServers.filesystem.command}"
        if [[ -z "$CMD_FS" ]]; then
           echo "gemini-cli filesystem mcp server not configured"
           exit 1
        fi

        # Check filesystem args
        FS_ARGS="${builtins.elemAt config.gemini.cli.mcpServers.filesystem.args 0}"
        if [[ "$FS_ARGS" != "/tmp" ]]; then
           echo "gemini-cli filesystem mcp server args incorrect: $FS_ARGS"
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
