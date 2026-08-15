# cline (Cline autonomous coding agent CLI) - bun-compiled binary in the
# @cline/cli-linux-x64 npm tarball (package/bin/cline). Ported onto the naked base.
{
  system,
  pins,
}:
let
  mkBinary = import ../mk/binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "cline";
  hashesFile = ../../packages/cline/hashes.json;
  urlTemplate = "https://registry.npmjs.org/@cline/cli-linux-x64/-/cli-linux-x64-{version}.tgz";
  unpack = "tar";
  binary = "package/bin/cline";
  kind = "loader";
  # A non-empty setEnv is required: mk-binary's empty-setEnv while-loop returns 1
  # under `set -e` and aborts the build before chmod. Marker var is harmless.
  setEnv = {
    CLINE_NIX_WRAPPED = "1";
  };
}
