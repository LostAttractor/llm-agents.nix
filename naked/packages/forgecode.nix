# forgecode (`forge`) — dynamic single-file binary. Ported onto the naked base
# (patchelf if dynamic; left intact if the release is static).
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  pname = "forgecode";
  version = "2.13.21";
  mainProgram = "forge";
  src = fetchurl {
    url = "https://github.com/tailcallhq/forgecode/releases/download/v2.13.21/forge-x86_64-unknown-linux-gnu";
    hash = "sha256-MArPaeOepaRS5lRPMZFHAxehQia2sakYIclYFeB6i4g=";
  };
  unpack = "none";
  kind = "patchelf";
}
