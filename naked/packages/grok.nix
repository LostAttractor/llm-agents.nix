# grok (xAI CLI) — bun-compiled single-file binary. Ported onto the naked base.
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  system = "x86_64-linux";
  pname = "grok";
  version = "1.0.3";
  src = fetchurl {
    url = "https://storage.googleapis.com/grok-build-public-artifacts/cli/grok-1.0.3-linux-x86_64";
    hash = "sha256-Kn1G3qP77QZ+QHIli4NdQB4BfWhI3JliefD7PWaKCWE=";
  };
  unpack = "none";
  kind = "loader";
}
