{
  inputs,
  pkgs,
  system,
  ...
}:

let
  apiKeyFilepath = "file.token";
  result = inputs.home-manager-unstable.lib.homeManagerConfiguration {
    pkgs = import inputs.nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        inputs.self.overlays.flake
      ];
    };
    modules = [
      inputs.self.homeManagerModules.gemini-cli
      {
        home.stateVersion = "25.11";
        home.username = "jdoe";
        home.homeDirectory = "/test";
        programs.gemini-cli = {
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
        ${(inputs.nixtest.lib { inherit pkgs; }).helpers.scriptHelpers}
        # We can verify the JSON content generated in the files.
        CONFIG_JSON="${result.config.home.file.".gemini/settings.json".text}"
        
        # Check buildkite
        CMD_BUILDKITE=$(echo "$CONFIG_JSON" | ${pkgs.jq}/bin/jq -r '.mcpServers.buildkite.command')
        if [[ -z "$CMD_BUILDKITE" || "$CMD_BUILDKITE" == "null" ]]; then
           echo "gemini buildkite mcp server not configured"
           exit 1
        fi

        # Check git
        CMD_GIT=$(echo "$CONFIG_JSON" | ${pkgs.jq}/bin/jq -r '.mcpServers.git.command')
        if [[ -z "$CMD_GIT" || "$CMD_GIT" == "null" ]]; then
           echo "gemini git mcp server not configured"
           exit 1
        fi

        # Check filesystem
        CMD_FS=$(echo "$CONFIG_JSON" | ${pkgs.jq}/bin/jq -r '.mcpServers.filesystem.command')
        if [[ -z "$CMD_FS" || "$CMD_FS" == "null" ]]; then
           echo "gemini filesystem mcp server not configured"
           exit 1
        fi
        
        # Check filesystem args
        FS_ARGS=$(echo "$CONFIG_JSON" | ${pkgs.jq}/bin/jq -r '.mcpServers.filesystem.args[0]')
        if [[ "$FS_ARGS" != "/tmp" ]]; then
           echo "gemini filesystem mcp server args incorrect: $FS_ARGS"
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
      actual = result.config.programs.gemini-cli.settings.mcpServers.buildkite.env;
    }
    {
      name = "args";
      type = "unit";
      expected = [ "stdio" ];
      actual = result.config.programs.gemini-cli.settings.mcpServers.buildkite.args;
    }
  ];
}
