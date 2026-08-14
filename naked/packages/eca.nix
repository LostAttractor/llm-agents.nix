# eca (Editor Code Assistant) - dynamic GraalVM native binary. Ported from
# packages/eca onto the naked base: fetch the release zip, unzip, patchelf to
# the pinned glibc + zlib. No nixpkgs.
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk-binary.nix;
  pinned = import ../pinned.nix;
in
mkBinary {
  pname = "eca";
  version = "0.153.1";
  src = fetchurl {
    url = "https://github.com/editor-code-assistant/eca/releases/download/0.153.1/eca-native-linux-amd64.zip";
    hash = "sha256-PPGaLdF3ovWT+CtJXZ5UdzaGvrtRozR2soq4WOLK+G0=";
  };
  unpack = "zip";
  binary = "eca";
  kind = "patchelf";
  libs = [ pinned.zlib ];
}
