# kilocode-cli (`kilocode`) — bun-compiled binary in an npm tarball (package/).
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
  pname = "kilocode-cli";
  version = "7.4.21";
  mainProgram = "kilocode";
  src = fetchurl {
    url = "https://registry.npmjs.org/@kilocode/cli-linux-x64/-/cli-linux-x64-7.4.21.tgz";
    hash = "sha256-seziO95kYduxvT/VQ5SWPNB5OpIShi7dftyUjWCbA/4=";
  };
  unpack = "tar";
  binary = "package/bin/kilo";
  kind = "loader";
}
