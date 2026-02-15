{
  lib,
  callPackage,
  callPackages,
  fetchFromGitHub,
  makeWrapper,
  ast-grep,
  uv2nix,
  pyproject,
  pyproject-build-systems,
  python313,
}: let
  src = fetchFromGitHub {
    owner = "ast-grep";
    repo = "ast-grep-mcp";
    rev = "e45cb2d0a43cb52ce05e8b6c19e94714a1170460";
    hash = "sha256-flYat4BR7FtiP+jSs9AvRF3QIILiaFLqM055rybhBPs=";
  };

  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = builtins.toString src;
  };

  workspaceOverlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  pythonSet =
    (callPackage pyproject.build.packages {
      python = python313;
    }).overrideScope
    (
      lib.composeManyExtensions [
        pyproject-build-systems.overlays.default
        workspaceOverlay
      ]
    );

  inherit (callPackages pyproject.build.util {}) mkApplication;

  app = mkApplication {
    venv = pythonSet.mkVirtualEnv "ast-grep-mcp-venv" workspace.deps.default;
    package = pythonSet.sg-mcp;
  };
in
  # Wrap the application to include ast-grep CLI in PATH
  app.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [makeWrapper];
    postFixup = ''
      ${oldAttrs.postFixup or ""}
      wrapProgram $out/bin/ast-grep-server \
        --prefix PATH : ${lib.makeBinPath [ast-grep]}
    '';

    meta =
      (oldAttrs.meta or {})
      // {
        description = "MCP server for ast-grep structural code search";
        homepage = "https://github.com/ast-grep/ast-grep-mcp";
        license = lib.licenses.mit;
        mainProgram = "ast-grep-server";
      };
  })
