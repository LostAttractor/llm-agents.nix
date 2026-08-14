# coderabbit-cli — bun-compiled binary in a zip. Ported onto the naked base.
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  system = "x86_64-linux";
  pname = "coderabbit-cli";
  version = "0.7.2";
  mainProgram = "coderabbit";
  src = fetchurl {
    url = "https://cli.coderabbit.ai/releases/0.7.2/coderabbit-linux-x64.zip";
    hash = "sha256-Mt06WhI4+mjrfPqVzBnPatSYCIJYnGFsDjALkg8buGU=";
  };
  unpack = "zip";
  binary = "coderabbit";
  kind = "loader";
}
