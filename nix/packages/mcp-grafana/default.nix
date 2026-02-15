{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule (finalAttrs: {
  pname = "mcp-grafana";
  version = "0.4.2";

  src = fetchFromGitHub {
    owner = "grafana";
    repo = "mcp-grafana";
    tag = "v${finalAttrs.version}";
    hash = "sha256-3w6xnDAcuDMZPr6lGGh0FpcyG2fRpkeVcJlZMdszu/g=";
  };

  vendorHash = "sha256-61nn/p6Un+uHuPK4hipJ3A2DhAEqpWTGefM8ENAOP1E=";

  ldflags = [
    "-s"
    "-w"
  ];

  __darwinAllowLocalNetworking = true;

  doInstallCheck = true;

  meta = {
    changelog = "https://github.com/grafana/mcp-grafana/releases/tag/v${finalAttrs.version}";
    description = "MCP server for Grafana";
    homepage = "https://github.com/grafana/mcp-grafana";
    license = lib.licenses.asl20;
    mainProgram = "mcp-grafana";
    maintainers = with lib.maintainers; [roman];
  };
})
