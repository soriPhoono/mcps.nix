{
  pkgs,
  config,
  ...
}:
with pkgs;
  mkShell {
    packages = [
      nil
      alejandra
    ];

    shellHook = ''
      ${config.pre-commit.shellHook}
    '';
  }
