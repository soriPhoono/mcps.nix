{
  lib,
  buildGoModule,
  fetchFromGitHub,
  symlinkJoin,
  makeWrapper,
}:

let
  version = "0.2.1";

  github-mcp-server = buildGoModule {
    name = "github-mcp-server";
    inherit version;

    src = fetchFromGitHub {
      owner = "github";
      repo = "github-mcp-server";
      rev = "v${version}";
      sha256 = "sha256-vbL96EXzgbjqVJaKizYIe8Fne60CVx7v/5ya9Xx3JvA=";
    };

    vendorHash = "sha256-LjwvIn/7PLZkJrrhNdEv9J6sj5q3Ljv70z3hDeqC5Sw=";

    meta = with lib; {
      description = "GitHub's official MCP Server";
      homepage = "https://github.com/github/github-mcp-server";
      license = licenses.mit;
      maintainers = with maintainers; [ roman ];
    };
  };

in
symlinkJoin {
  inherit (github-mcp-server) name version meta;
  buildInputs = [ makeWrapper ];
  paths = [ github-mcp-server ];

  # Add override to musta.ch server using GH_HOST.
  # https://github.com/github/github-mcp-server?tab=readme-ov-file#github-enterprise-server
  postBuild = ''
    wrapProgram $out/bin/github-mcp-server \
      --set-default GH_HOST git.musta.ch
  '';
}
