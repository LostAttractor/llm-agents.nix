# jules (Google CLI) — Go binary in a tarball. Reuses the repo's shared source
# of truth: version + hash from packages/jules/hashes.json (what nix-update
# bumps), url from the interpolated template. No duplicated, drift-prone hash.
{
  system,
  pins,
}:
let
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "jules";
  hashesFile = ../../packages/jules/hashes.json;
  urlTemplate = "https://storage.googleapis.com/jules-cli/v{version}/jules_external_v{version}_linux_amd64.tar.gz";
  unpack = "tar";
  binary = "jules";
  kind = "patchelf";
}
