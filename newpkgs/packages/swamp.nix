# swamp - ported onto the naked base
# Deterministic automation for AI agents. The release artifact is a
# bun --compile single-file binary (tar.gz with `swamp` at the root), so it must
# be run byte-intact through the pinned loader; patchelf shifts the appended JS
# payload and breaks bun's "standalone binary section" lookup.
#
# Reuses the repo's shared source of truth: version + hash from
# packages/swamp/hashes.json (what nix-update bumps), url from the interpolated
# template. No duplicated, drift-prone hash.
{ system, pins }:
let
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "swamp";
  hashesFile = ../../packages/swamp/hashes.json;
  urlTemplate = "https://artifacts.swamp-club.com/swamp/{version}/binary/linux/x86_64/swamp-{version}-binary-linux-x86_64.tar.gz";
  unpack = "tar";
  binary = "swamp";
  kind = "loader";
  # A non-empty setEnv is required: mk-binary's empty-setEnv while-loop returns 1
  # under `set -e` and aborts the build before chmod. Marker var is harmless.
  setEnv = {
    SWAMP_NAKED = "1";
  };
}
