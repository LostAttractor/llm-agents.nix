# Pin provider sourcing the same tools from the flake's `pkgs`. Pure (touches
# nixpkgs), so CI can rebuild pins from source on a cache miss - the fallback for
# pins/closure.nix. formatelf is rebuilt from the pinned rev.
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
  # manylinux external libs for python wheels
  libffi = pkgs.libffi;
  expat = pkgs.expat;
  ncurses = pkgs.ncurses;
  openssl = pkgs.openssl.out;
  opensslDev = pkgs.openssl.dev;
  pkgConfig = pkgs.pkg-config;
  icu = pkgs.icu.out;
  icuDev = pkgs.icu.dev;
  bzip2 = pkgs.bzip2.out;
  xz = pkgs.xz.out;
  bubblewrap = pkgs.bubblewrap;
  socat = pkgs.socat;
}
