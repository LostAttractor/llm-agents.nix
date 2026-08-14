# amp (Sourcegraph) - bun-compiled single-file binary + ripgrep runtime dep.
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
  pname = "amp";
  version = "0.0.1786738049-g32e30e";
  src = fetchurl {
    url = "https://static.ampcode.com/cli/0.0.1786738049-g32e30e/amp-linux-x64";
    hash = "sha256-drrdTPxsIAXi3xSkBJM+g9rZ3TDLKTEUSaODepbv3pc=";
  };
  unpack = "none";
  kind = "loader";
  runtimePkgs = [ pins.ripgrep ];
}
