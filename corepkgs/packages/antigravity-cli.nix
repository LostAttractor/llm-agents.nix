# antigravity-cli - ported onto the naked base
{ system, pins }:
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk/binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "antigravity-cli";
  version = "1.1.13";
  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.1.13-6057583128215552/linux-x64/cli_linux_x64.tar.gz";
    hash = "sha512-icaIG2wZmcuCNucYHCGSro83KwQTOWwPe8/4PSesnAzBICeVzA1insHsv0k30cKUz09eT5+OBbHpcuJxmDE0Qg==";
  };
  unpack = "tar";
  binary = "antigravity";
  mainProgram = "agy";
  kind = "patchelf";
  libs = [ pins.gccLib ];
}
