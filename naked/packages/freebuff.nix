# freebuff - ported onto the naked base
{ system, pins }:
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "freebuff";
  version = "0.0.149";
  src = fetchurl {
    url = "https://github.com/CodebuffAI/codebuff-community/releases/download/freebuff-v0.0.149/freebuff-linux-x64.tar.gz";
    hash = "sha256-PxHyw7Rx8V29qYI90ftSXWe18WwCk755bz/BUmczyj0=";
  };
  unpack = "tar";
  binary = "freebuff";
  mainProgram = "freebuff";
  kind = "loader";
  runtimePkgs = [ pins.ripgrep ];
}
