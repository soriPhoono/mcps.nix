{
  uv2nix,
  pyproject,
  pyproject-build-systems,
  lib,
  callPackage,
  callPackages,
  fetchFromGitHub,
  buildNpmPackage,
  nodejs,
  python311,
  symlinkJoin,
}:

let
  masterSrc = fetchFromGitHub {
    owner = "modelcontextprotocol";
    repo = "servers";
    rev = "master";
    sha256 = "sha256-X4Vr7QzAnZzWbotF1RFPgBoilG6apJypXRowvbpy8Mw=";
  };

  gitServer =
    let
      workspace = uv2nix.lib.workspace.loadWorkspace {
        workspaceRoot = "${masterSrc}/src/git";
      };
      workspaceOverlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };
      pythonSet =
        (callPackage pyproject.build.packages {
          python = python311;
        }).overrideScope
          (
            lib.composeManyExtensions [
              pyproject-build-systems.overlays.default
              workspaceOverlay
            ]
          );
      inherit (callPackages pyproject.build.util { }) mkApplication;
    in
    mkApplication {
      venv = pythonSet.mkVirtualEnv "mcp-server-git-venv" workspace.deps.default;
      package = pythonSet.mcp-server-git;
    };

  fetchServer =
    let
      workspace = uv2nix.lib.workspace.loadWorkspace {
        workspaceRoot = "${masterSrc}/src/fetch";
      };
      workspaceOverlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };
      pythonSet =
        (callPackage pyproject.build.packages {
          python = python311;
        }).overrideScope
          (
            lib.composeManyExtensions [
              pyproject-build-systems.overlays.default
              workspaceOverlay
            ]
          );
      inherit (callPackages pyproject.build.util { }) mkApplication;
    in
    mkApplication {
      venv = pythonSet.mkVirtualEnv "mcp-server-fetch-venv" workspace.deps.default;
      package = pythonSet.mcp-server-fetch;
    };

  jsServers = buildNpmPackage {
    pname = "mcp-servers";
    version = "master";
    src = "${masterSrc}";
    npmDepsHash = "sha256-QJo4EojeHBHTuKdv9QObGd07/z/y39Uq3JIHYGn2mCo=";
    patches = [
      ./main-branch-node-packages-lock.patch
    ];
    PUPPETEER_SKIP_DOWNLOAD = 1;
    buildInputs = [ nodejs ];
    installPhase = ''
      mkdir $out
      mkdir $out/bin
      cp -R src $out
      cp -R node_modules $out
      ln -s $out/node_modules/@modelcontextprotocol/server-gdrive/dist/index.js $out/bin/mcp-server-gdrive
      ln -s $out/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js $out/bin/mcp-server-filesystem 
      ln -s $out/node_modules/@modelcontextprotocol/server-brave-search/dist/index.js $out/bin/mcp-server-brave-search
      ln -s $out/node_modules/@modelcontextprotocol/server-everart/dist/index.js $out/bin/mcp-server-everart
      ln -s $out/node_modules/@modelcontextprotocol/server-everything/dist/index.js $out/bin/mcp-server-everything
      ln -s $out/node_modules/@modelcontextprotocol/server-github/dist/index.js $out/bin/mcp-server-github
      ln -s $out/node_modules/@modelcontextprotocol/server-gitlab/dist/index.js $out/bin/mcp-server-gitlab
      ln -s $out/node_modules/@modelcontextprotocol/server-google-maps/dist/index.js $out/bin/mcp-server-google-maps
      ln -s $out/node_modules/@modelcontextprotocol/server-memory/dist/index.js $out/bin/mcp-server-memory
      ln -s $out/node_modules/@modelcontextprotocol/server-postgres/dist/index.js $out/bin/mcp-server-postgres
      ln -s $out/node_modules/@modelcontextprotocol/server-puppeteer/dist/index.js $out/bin/mcp-server-puppeteer
      ln -s $out/node_modules/@modelcontextprotocol/server-slack/dist/index.js $out/bin/mcp-server-slack
    '';
    meta = with lib; {
      description = "Google Drive Model Context Protocol server";
      homepage = "https://modelcontextprotocol.io";
      license = licenses.mit;
      maintainers = with maintainers; [ roman ];
    };
  };

in
symlinkJoin {
  name = "mcp-servers";
  paths = [
    gitServer
    fetchServer
    jsServers
  ];
}
