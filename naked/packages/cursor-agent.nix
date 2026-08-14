# cursor-agent - dynamic binary shipped as a whole package dir (dir-install)
# plus a coreutils runtime dep.
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
  pname = "cursor-agent";
  version = "2026.08.11-e8db854";
  src = fetchurl {
    url = "https://downloads.cursor.com/lab/2026.08.11-e8db854/linux/x64/agent-cli-package.tar.gz";
    hash = "sha256-v/9L9vTp3TDB0O8KcLYHewdAFd0pSOTFBoXVOv3Pzlo=";
  };
  unpack = "tar";
  installDir = "dist-package";
  kind = "patchelf";
  libs = [ pins.zlib ]; # a bundled native node module (file_service.*.node) needs libz
  runtimePkgs = [ pins.coreutils ];
}
