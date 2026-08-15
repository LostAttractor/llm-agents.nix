# memvid-cli (`memvid`) - a jpackage-style native launcher with a bundled JVM.
# The `memvid` ELF and its sibling .so files (libjvm, libawt, libtika_native,
# ...) live in one npm tarball dir; dir-install the whole tree so intra-tree
# deps resolve via $ORIGIN. The binary itself needs openssl + zlib; the bundled
# AWT/X11/sound libs are optional (headless CLI) so leave their SONAMEs missing,
# like autoPatchelfIgnoreMissingDeps.
{
  system,
  pins,
}:
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk/binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "memvid-cli";
  version = "2.0.160";
  mainProgram = "memvid";
  src = fetchurl {
    url = "https://registry.npmjs.org/@memvid/cli-linux-x64/-/cli-linux-x64-2.0.160.tgz";
    hash = "sha256-d0Yy+m9HOqGYftoSSIRMCIjayxoyCritn2zQL5Je3lw=";
  };
  unpack = "tar";
  installDir = "package";
  entrypoint = "memvid";
  kind = "patchelf";
  libs = [
    pins.openssl
    pins.zlib
  ];
  # Force the bundled JVM headless so the optional AWT/X11/sound libs below are
  # never dlopen'd - the CLI has no GUI. Keeps ignoreMissing honest.
  setEnv = {
    _JAVA_AWT_HEADLESS = "true";
  };
  ignoreMissing = [
    "libasound.so.2"
    "libX11.so.6"
    "libXext.so.6"
    "libXi.so.6"
    "libXrender.so.1"
    "libXtst.so.6"
  ];
}
