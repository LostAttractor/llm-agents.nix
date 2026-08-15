# coderabbit-cli — bun-compiled binary in a zip. Ported onto the naked base.
# Reuses the repo's shared source of truth: version + hash from
# packages/coderabbit-cli/hashes.json (what nix-update bumps), url from the
# interpolated template. No duplicated, drift-prone hash.
{
  system,
  pins,
}:
let
  mkBinary = import ../mk/binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "coderabbit-cli";
  mainProgram = "coderabbit";
  hashesFile = ../../packages/coderabbit-cli/hashes.json;
  urlTemplate = "https://cli.coderabbit.ai/releases/{version}/coderabbit-linux-x64.zip";
  unpack = "zip";
  binary = "coderabbit";
  kind = "loader";
}
