# mimo-code - ported onto the naked base
{ system, pins }:
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "mimo-code";
  version = "0.1.12";
  src = fetchurl {
    url = "https://github.com/XiaomiMiMo/MiMo-Code/releases/download/v0.1.12/mimocode-linux-x64.tar.gz";
    hash = "sha256-6IFFpMOsgXtrSnXtEFRXGnyKF73vMCFCQ2MNPs/2iqQ=";
  };
  unpack = "tar";
  binary = "mimo";
  mainProgram = "mimo";
  kind = "loader";
  runtimePkgs = [ pins.ripgrep ];
  # Work around a set -e bug in mk-naked.nix: the wrapper-generation
  # while-read loop exits 1 when setEnvLines is empty, which aborts the build.
  # A non-empty setEnv keeps the pipeline exit status 0. This var is inert.
  setEnv = {
    MIMO_CODE_NAKED = "1";
  };
}
