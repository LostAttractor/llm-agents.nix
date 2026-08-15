# open-code-review (`ocr`, Alibaba) — dynamic Go single-file binary. Reuses the
# repo's shared source of truth: version + hash from
# packages/open-code-review/hashes.json (what nix-update bumps), url from the
# interpolated template. No duplicated, drift-prone hash.
{
  system,
  pins,
}:
let
  mkBinary = import ../mk/binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "open-code-review";
  hashesFile = ../../packages/open-code-review/hashes.json;
  urlTemplate = "https://github.com/alibaba/open-code-review/releases/download/v{version}/opencodereview-linux-amd64";
  mainProgram = "ocr";
  unpack = "none";
  kind = "patchelf";
}
