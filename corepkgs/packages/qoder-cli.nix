# qoder-cli (`qodercli`) - bun-compiled binary in a tarball, ported onto the naked base.
{ system, pins }:
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk/binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "qoder-cli";
  version = "1.1.22";
  mainProgram = "qodercli";
  src = fetchurl {
    url = "https://qoder-ide.oss-accelerate.aliyuncs.com/qodercli/releases/1.1.22/qodercli-linux-x64.tar.gz";
    hash = "sha256-nrlsdKG9E4v82F6Yyz9KP5/EUQ/tMotrE/JZDnQZ5LE=";
  };
  unpack = "tar";
  binary = "qodercli";
  kind = "loader";
  # Disable self-update: the store binary is read-only, so an in-place update
  # attempt would just fail. This also gives mkBinary a non-empty setEnv.
  setEnv = {
    QODER_DISABLE_AUTO_UPDATE = "1";
  };
}
