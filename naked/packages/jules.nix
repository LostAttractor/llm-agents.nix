# jules (Google CLI) — Go binary in a tarball.
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  pname = "jules";
  version = "0.1.42";
  src = fetchurl {
    url = "https://storage.googleapis.com/jules-cli/v0.1.42/jules_external_v0.1.42_linux_amd64.tar.gz";
    hash = "sha256-c869LI+Jubsk703MuM15Q8y2npmzfeJnwvV5Mjen0QM=";
  };
  unpack = "tar";
  binary = "jules";
  kind = "patchelf";
}
