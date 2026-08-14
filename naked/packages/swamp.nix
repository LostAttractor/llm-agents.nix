# swamp - ported onto the naked base
# Deterministic automation for AI agents. The release artifact is a
# bun --compile single-file binary (tar.gz with `swamp` at the root), so it must
# be run byte-intact through the pinned loader; patchelf shifts the appended JS
# payload and breaks bun's "standalone binary section" lookup.
{ system, pins }:
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "swamp";
  version = "20260814.171226.0-sha.14540c33";
  src = fetchurl {
    url = "https://artifacts.swamp-club.com/swamp/20260814.171226.0-sha.14540c33/binary/linux/x86_64/swamp-20260814.171226.0-sha.14540c33-binary-linux-x86_64.tar.gz";
    hash = "sha256-QYbb18nGgxtyP46eqkw8bn/CljUsAAOh+WG5sFRBZpU=";
  };
  unpack = "tar";
  binary = "swamp";
  kind = "loader";
  # A non-empty setEnv is required: mk-binary's empty-setEnv while-loop returns 1
  # under `set -e` and aborts the build before chmod. Marker var is harmless.
  setEnv = {
    SWAMP_NAKED = "1";
  };
}
