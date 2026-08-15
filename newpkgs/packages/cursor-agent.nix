# cursor-agent - dynamic binary shipped as a whole package dir (dir-install)
# plus a coreutils runtime dep. Reuses the repo's shared source of truth:
# version + hash from packages/cursor-agent/hashes.json (what nix-update bumps),
# url from the interpolated template. No duplicated, drift-prone hash.
{
  system,
  pins,
}:
let
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "cursor-agent";
  hashesFile = ../../packages/cursor-agent/hashes.json;
  urlTemplate = "https://downloads.cursor.com/lab/{version}/linux/x64/agent-cli-package.tar.gz";
  unpack = "tar";
  installDir = "dist-package";
  kind = "patchelf";
  libs = [ pins.zlib ]; # a bundled native node module (file_service.*.node) needs libz
  runtimePkgs = [ pins.coreutils ];
}
