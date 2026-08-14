# Pin provider for the flake: the same tools, but sourced from the flake's
# `pkgs` instead of builtins.storePath. PURE, so the naked layer can be a flake
# output that nixbot builds on the real per-arch builders. Eval now touches
# nixpkgs (unlike pins-store.nix), which is fine for a CI build check.
#
# formatelf is Mic92's patchelf replacement (the repo's own auto-patchelf tool),
# rebuilt from the same rev the repo pins.
pkgs:
let
  formatelf = pkgs.rustPlatform.buildRustPackage {
    pname = "formatelf";
    version = "0-unstable-2026-08-11";
    src = pkgs.fetchFromGitHub {
      owner = "Mic92";
      repo = "formatelf";
      rev = "2b36d819b48c0bfd4a084e6f0ce430633d8ee5f4";
      hash = "sha256-wWCpCxVogWKo/ivGfmAmD8YE8H4CQfs52lMdKsELK/w=";
    };
    cargoHash = "sha256-+chzNYelw+fcWhIMSbJgVyOD48vV/Z6Cg5nhbfs16Xs=";
    doCheck = false;
  };
in
{
  inherit formatelf;
  glibc = pkgs.glibc;
  gccLib = pkgs.stdenv.cc.cc.lib;
  zlib = pkgs.zlib;
  zstd = pkgs.zstd;
  ripgrep = pkgs.ripgrep;
  coreutils = pkgs.coreutils;
}
