# grok (xAI CLI) — bun-compiled single-file binary. Ported onto the naked base.
# Reuses the repo's shared source of truth: version + hash from
# packages/grok/hashes.json (what nix-update bumps), url from the interpolated
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
  pname = "grok";
  hashesFile = ../../packages/grok/hashes.json;
  urlTemplate = "https://storage.googleapis.com/grok-build-public-artifacts/cli/grok-{version}-linux-x86_64";
  unpack = "none";
  kind = "loader";
}
