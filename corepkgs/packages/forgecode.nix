# forgecode (`forge`) — dynamic single-file binary. Ported onto the naked base
# (patchelf if dynamic; left intact if the release is static). Reuses the repo's
# shared source of truth: version + hash from packages/forgecode/hashes.json
# (what nix-update bumps), url from the interpolated template. No duplicated,
# drift-prone hash.
{
  system,
  pins,
}:
let
  mkBinary = import ../mk/binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "forgecode";
  mainProgram = "forge";
  hashesFile = ../../packages/forgecode/hashes.json;
  urlTemplate = "https://github.com/tailcallhq/forgecode/releases/download/v{version}/forge-x86_64-unknown-linux-gnu";
  unpack = "none";
  kind = "patchelf";
}
