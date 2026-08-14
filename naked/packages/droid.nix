# droid (Factory AI CLI) - a bun --compile single-file binary that bundles its
# own ripgrep. Ported from packages/droid onto the naked base: fetch droid + rg,
# loader-wrap droid (patchelf would segfault a bun-compiled binary), bundle rg
# onto PATH. No nixpkgs.
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  system = "x86_64-linux";
  pname = "droid";
  version = "0.194.1";
  src = fetchurl {
    url = "https://downloads.factory.ai/factory-cli/releases/0.194.1/linux/x64/droid";
    hash = "sha256-qTQSoRNI75Q0JsIEJQShl670gwFJS52+GQWJ3rH0n4c=";
  };
  unpack = "none";
  kind = "loader";
  runtimeBins = [
    {
      name = "rg";
      src = fetchurl {
        url = "https://downloads.factory.ai/ripgrep/linux/x64/rg";
        hash = "sha256-viR2yXY0K5IWYRtKhMG8LsZIjsXHkeoBmhMnJ2RO8Zw=";
      };
    }
  ];
}
