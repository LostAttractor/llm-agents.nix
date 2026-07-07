{
  pkgs,
  flake,
  perSystem,
  ...
}:
pkgs.callPackage ./package.nix {
  inherit flake;
  nodejs = pkgs.nodejs_24;
  inherit (perSystem.self) buildNpmPackage versionCheckHomeHook;
}
