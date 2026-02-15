{
  lib,
  fetchFromGitHub,
  buildNpmPackage,
}: let
  version = "1.7.0";
in
  buildNpmPackage rec {
    pname = "mcp-server-asana";
    inherit version;

    src = fetchFromGitHub {
      owner = "roychri";
      repo = "mcp-server-asana";
      rev = "59e85f6dd976a5e68bf00ee352a47ccf4d0b02e8";
      sha256 = "sha256-mASlQ06UplgTjA9qzy4F3R2NCvvZnrRzcljL36I0nRQ=";
    };

    npmDepsHash = "sha256-X+HUtZeazGXRWK1WG+uKSLtN+G2jI6UTUjiaVaR1DhQ=";

    makeConfigure = true;

    meta = with lib; {
      description = "MCP server for Asana integration";
      homepage = "https://github.com/roychri/mcp-server-asana";
      license = licenses.mit;
      maintainers = with maintainers; [roman];
      platforms = platforms.all;
    };
  }
