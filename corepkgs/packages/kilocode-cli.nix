# kilocode-cli (`kilocode`) — bun-compiled binary in an npm tarball (package/).
# Reuses the repo's shared source of truth: version + hash from
# packages/kilocode-cli/hashes.json (what nix-update bumps), url from the
# interpolated template. No duplicated, drift-prone hash. x86_64-only.
{
  system,
  pins,
}:
let
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "kilocode-cli";
  mainProgram = "kilocode";
  hashesFile = ../../packages/kilocode-cli/hashes.json;
  urlTemplate = "https://registry.npmjs.org/@kilocode/cli-linux-x64/-/cli-linux-x64-{version}.tgz";
  unpack = "tar";
  binary = "package/bin/kilo";
  kind = "loader";
}
