# freebuff - ported onto the naked base. Reuses the repo's shared source of
# truth: version + hash from packages/freebuff/hashes.json (what nix-update
# bumps), url from the interpolated template. No duplicated, drift-prone hash.
{ system, pins }:
let
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "freebuff";
  hashesFile = ../../packages/freebuff/hashes.json;
  urlTemplate = "https://github.com/CodebuffAI/codebuff-community/releases/download/freebuff-v{version}/freebuff-linux-x64.tar.gz";
  unpack = "tar";
  binary = "freebuff";
  mainProgram = "freebuff";
  kind = "loader";
  runtimePkgs = [ pins.ripgrep ];
}
