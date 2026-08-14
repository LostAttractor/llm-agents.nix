# open-code-review (`ocr`, Alibaba) — dynamic Go single-file binary.
{
  system,
  pins,
}:
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "open-code-review";
  version = "1.9.2";
  mainProgram = "ocr";
  src = fetchurl {
    url = "https://github.com/alibaba/open-code-review/releases/download/v1.9.2/opencodereview-linux-amd64";
    hash = "sha256-Fe1gUwX8Z5YE7Q9fqHFdtQWvgcEOy4p4RtVkK85Lg04=";
  };
  unpack = "none";
  kind = "patchelf";
}
