# Dogfood: build formatelf (the ELF patcher we otherwise pin) FROM SOURCE, fully
# nixpkgs-free, via mk/cargo.nix. The pinned formatelf bootstraps this one by
# post-link-patching the build's executables; this is the proof that the naked
# rust + zig-cc + cargo-vendor path produces a working binary. It is also the
# reference caller for mkCargo.
{
  system,
  pins,
}:
let
  fetchurl = import ./fetch/fetchurl.nix;
  mkCargo = import ./mk/cargo.nix;
  rev = "2b36d819b48c0bfd4a084e6f0ce430633d8ee5f4";
in
mkCargo {
  inherit system pins;
  pname = "formatelf";
  src = fetchurl {
    url = "https://github.com/Mic92/formatelf/archive/${rev}.tar.gz";
    hash = "sha256-2hleJRn6xsSeE8ZMotXR29z1jOY1TLf9cOOp2YDZltY=";
  };
  cargoLock = ./packages/formatelf.Cargo.lock;
  binaries = [ "formatelf" ];
}
