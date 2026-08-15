# amp (Sourcegraph) - bun-compiled single-file binary + ripgrep runtime dep.
# Reuses the repo's shared source of truth: version + hash from
# packages/amp/hashes.json (what nix-update bumps), url from the interpolated
# template. No duplicated, drift-prone hash.
{
  system,
  pins,
}:
let
  mkBinary = import ../mk/binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "amp";
  hashesFile = ../../packages/amp/hashes.json;
  urlTemplate = "https://static.ampcode.com/cli/{version}/amp-linux-x64";
  unpack = "none";
  kind = "loader";
  runtimePkgs = [ pins.ripgrep ];
}
