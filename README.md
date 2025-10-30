# mcps.nix

A curated library of MCP (Model Context Protocol) server presets for [Claude
Code](https://claude.ai/code) that integrates with native Claude modules in
[devenv](https://github.com/cachix/devenv) and [Home
Manager](https://github.com/nix-community/home-manager).

## Overview

Both devenv and home-manager now have native support for Claude Code configuration:

- **home-manager**: `programs.claude-code`
- **devenv**: `claude.code`

This project provides reusable MCP server configurations (presets) that work with these
native modules, allowing you to easily enable and configure popular MCP servers without
manual JSON configuration.

## Features

- **Pre-configured MCP Servers**: Built-in presets for popular MCP servers including Asana,
  GitHub, Buildkite, Git, Filesystem, LSP integrations, and more

- **Secure Credential Management**: Support for reading API tokens from files instead of
  environment variables

- **Native Integration**: Works with upstream Claude modules in both devenv and home-manager

- **Two Home Manager Options**: Choose between native integration or custom script-based
  installation

- **Extensible**: Add custom MCP servers alongside presets

## Quick Start

Add this flake's overlay to your nixpkgs import.

```nix
let
  pkgs = import nixpkgs {
    overlays = [ inputs.mcps.overlays.default ];
  };
in
# ...
```

### Using with devenv

Add to your devenv module configuration:

```nix
{
  imports = [ inputs.mcps.devenvModules.claude ];

  claude.code = {
    enable = true;
    mcps = {
      git.enable = true;
      filesystem = {
        enable = true;
        allowedPaths = [ "/path/to/your/project" ];
      };
      github = {
        enable = true;
        tokenFilepath = "/path/to/github-token";
      };
    };
  };
}
```

### Using with Home Manager

This project provides two Home Manager modules:

#### Option 1: Native Integration (Recommended)

Integrates with home-manager's native Claude Code support. MCP servers are managed through Nix and stored in the Nix store:

```nix
{
  imports = [ inputs.mcps.homeManagerModules.claude ];

  programs.claude-code = {
    enable = true;
    mcps = {
      git.enable = true;
      filesystem = {
        enable = true;
        allowedPaths = [ "${config.home.homeDirectory}/Projects" ];
      };
      asana = {
        enable = true;
        tokenFilepath = "/var/run/agenix/asana.token";
      };
    };
  };
}
```

#### Option 2: Script-based Installation

Uses the Claude CLI to manage MCP servers in `~/.claude.json`. This approach is useful if you:
- Want your MCP server configurations to persist in `~/.claude.json`
- Need to manually manage or edit MCP servers outside of Nix
- Prefer keeping custom MCP configurations in your home directory

```nix
{
  imports = [ inputs.mcps.homeManagerModules.claude-install ];

  programs.claude-code = {
    enable = true;
    mcps = {
      git.enable = true;
      buildkite = {
        enable = true;
        apiKeyFilepath = "/path/to/buildkite-token";
      };
    };
  };
}
```

## Available MCP Servers

### Built-in Presets

| Preset | Description | Source |
|--------|-------------|--------|
| **asana** | Asana task management integration with API token support | [roychri/mcp-server-asana](https://github.com/roychri/mcp-server-asana) |
| **buildkite** | Buildkite CI/CD pipeline integration and monitoring | [buildkite/buildkite-mcp-server](https://github.com/buildkite/buildkite-mcp-server) |
| **fetch** | Web content fetching with proxy support and custom user agents | [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) |
| **filesystem** | Local filesystem access with configurable path restrictions | [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) |
| **git** | Git repository operations and version control | [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) |
| **github** | GitHub API integration with configurable toolsets (repos, issues, users, pull_requests, code_security) | [github/github-mcp-server](https://github.com/github/github-mcp-server) |
| **grafana** | Grafana monitoring, alerting, and dashboard management with multiple toolsets | [grafana/mcp-grafana](https://github.com/grafana/mcp-grafana) |
| **lsp-golang** | Language Server Protocol integration for Go development with configurable workspace | [isaacphi/mcp-language-server](https://github.com/isaacphi/mcp-language-server) |
| **lsp-nix** | Language Server Protocol integration for Nix development with configurable workspace | [isaacphi/mcp-language-server](https://github.com/isaacphi/mcp-language-server) |
| **lsp-python** | Language Server Protocol integration for Python development with configurable workspace | [isaacphi/mcp-language-server](https://github.com/isaacphi/mcp-language-server) |
| **lsp-rust** | Language Server Protocol integration for Rust development with configurable workspace | [isaacphi/mcp-language-server](https://github.com/isaacphi/mcp-language-server) |
| **lsp-typescript** | Language Server Protocol integration for TypeScript development with configurable workspace | [isaacphi/mcp-language-server](https://github.com/isaacphi/mcp-language-server) |
| **sequential-thinking** | Enhanced reasoning and knowledge graph capabilities | [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) |
| **time** | Time and timezone utilities with configurable local timezone | [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) |

## Module Structure

The project now provides focused modules that integrate with native Claude Code support:

- **`devenvModules.claude`**: Adds `claude.code.mcps` configuration to devenv's native `claude.code` module
- **`homeManagerModules.claude`**: Adds `programs.claude-code.mcps` configuration to home-manager's native Claude module
- **`homeManagerModules.claude-install`**: Alternative home-manager module that uses Claude CLI to manage `~/.claude.json`

All modules provide access to the same preset MCP server configurations, allowing you to easily enable popular MCP servers with simple boolean flags.

## Security Features

- **Credential File Support**: All MCP servers support reading credentials from files instead of environment variables
- **Path Restrictions**: Filesystem access is restricted to explicitly allowed paths
- **No Credential Exposure**: API tokens and keys are never exposed in the Nix store

## Contributing

See [CONTRIBUTE.md](./CONTRIBUTE.md) for development setup, testing, and contribution guidelines.

## License

This project is licensed under the MIT License.
