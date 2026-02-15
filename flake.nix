{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    nixDir.url = "github:roman/nixDir/v3";
    nixDir.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    home-manager-unstable.url = "github:nix-community/home-manager";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Used to run integration tests with nixosTest
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";

    mcp-nixos.url = "github:utensils/mcp-nixos/v1.0.3";
    mcp-nixos.inputs.nixpkgs.follows = "nixpkgs";

    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";

    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";

    ## Dependencies to build mcp-servers
    pyproject = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixtest.url = "gitlab:technofab/nixtest?dir=lib";

    systems.url = "github:nix-systems/default";
    systems.flake = false;

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import inputs.systems;

      imports = [
        inputs.devenv.flakeModule
        inputs.nixDir.flakeModule
        inputs.nixtest.flakeModule
        inputs.treefmt-nix.flakeModule
        inputs.git-hooks-nix.flakeModule
      ];

      nixDir = {
        root = ./.;
        enable = true;
        nixpkgsConfig = {
          allowUnfree = true;
        };
        installOverlays = [
          inputs.self.overlays.development
          inputs.self.overlays.default
        ];
        generateAllPackage = true;
      };

      flake.overlays = {
        development = _final: _prev: {
          inherit (inputs) uv2nix pyproject pyproject-build-systems;
        };
        default = _final: prev: {
          inherit (inputs.nixpkgs-unstable.legacyPackages.${prev.system}) github-mcp-server;
          inherit
            (inputs.self.packages.${prev.system})
            mcp-servers
            mcp-server-asana
            mcp-language-server
            mcp-grafana
            mcp-obsidian
            buildkite-mcp-server
            ast-grep-mcp
            ;
        };
      };

      perSystem = {
        pkgs,
        lib,
        system,
        config,
        ...
      }: {
        nixtest.suites = {
          "home-manager/claude" = import ./tests/home-manager-claude-tests.nix {
            inherit inputs pkgs system;
          };

          "home-manager/claude-install" = import ./tests/home-manager-claude-install-tests.nix {
            inherit inputs pkgs system;
          };

          "home-manager/gemini" = import ./tests/home-manager-gemini-tests.nix {
            inherit inputs pkgs system;
          };

          "home-manager/gemini-install" = import ./tests/home-manager-gemini-install-tests.nix {
            inherit inputs pkgs system;
          };

          "devenv/claude" = import ./tests/devenv-claude-tests.nix {
            inherit inputs pkgs system;
          };

          "devenv/gemini" = import ./tests/devenv-gemini-tests.nix {
            inherit inputs pkgs system;
          };
        };

        devShells.default = import ./shell.nix {
          inherit lib pkgs;
          config = {
            inherit (config) pre-commit;
          };
        };
        treefmt = import ./treefmt.nix {
          inherit lib pkgs;
        };
        pre-commit = import ./pre-commit.nix {
          inherit lib pkgs;
        };
      };
    };
}
