# eca (Editor Code Assistant) - dynamic GraalVM binary. Reuses the repo's shared
# source of truth: version + hash from packages/eca/hashes.json (what nix-update
# bumps), url from the interpolated template. No duplicated, drift-prone hash.
{
  system,
  pins,
}:
let
  mkBinary = import ../mk/binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "eca";
  hashesFile = ../../packages/eca/hashes.json;
  urlTemplate = "https://github.com/editor-code-assistant/eca/releases/download/{version}/eca-native-linux-amd64.zip";
  unpack = "zip";
  binary = "eca";
  kind = "patchelf";
  libs = [ pins.zlib ];
}
