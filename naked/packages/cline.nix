# cline (Cline autonomous coding agent CLI) - bun-compiled binary in the
# @cline/cli-linux-x64 npm tarball (package/bin/cline). Ported onto the naked base.
{
  system,
  pins,
}:
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "cline";
  version = "3.0.55";
  src = fetchurl {
    url = "https://registry.npmjs.org/@cline/cli-linux-x64/-/cli-linux-x64-3.0.55.tgz";
    hash = "sha256-ghh2+L0vIijC/dP+pxr50Jkgh6Ccq2uFlz6oVTiuuKU=";
  };
  unpack = "tar";
  binary = "package/bin/cline";
  kind = "loader";
  # A non-empty setEnv is required: mk-binary's empty-setEnv while-loop returns 1
  # under `set -e` and aborts the build before chmod. Marker var is harmless.
  setEnv = {
    CLINE_NIX_WRAPPED = "1";
  };
}
