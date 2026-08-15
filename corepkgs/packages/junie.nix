# junie (JetBrains) - a jpackage app-image: a native launcher (bin/junie) that
# finds its bundled JRE via ../lib. dir-install the whole junie-app tree, exec
# the nested launcher, and allow the JRE's optional AWT/sound/X11 libs to stay
# unresolved (the CLI never loads them) - like nixpkgs autoPatchelfIgnoreMissingDeps.
{
  system,
  pins,
}:
let
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "junie";
  hashesFile = ../../packages/junie/hashes.json;
  urlTemplate = "https://github.com/JetBrains/junie/releases/download/{version}/junie-release-{version}-linux-amd64.zip";
  unpack = "zip";
  installDir = "junie-app";
  entrypoint = "bin/junie";
  mainProgram = "junie";
  kind = "patchelf";
  libs = [ pins.zlib ];
  ignoreMissing = [
    "libasound.so.2"
    "libfreetype.so.6"
    "libharfbuzz.so.0"
    "libgif.so.7"
    "libjpeg.so.8"
    "liblcms2.so.2"
    "libpng16.so.16"
    "libpcsclite.so.1"
    "libwayland-client.so.0"
    "libwayland-cursor.so.0"
    "libX11.so.6"
    "libXext.so.6"
    "libXi.so.6"
    "libXrender.so.1"
    "libXtst.so.6"
    "libfontconfig.so.1"
  ];
}
