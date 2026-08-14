# opencode - bun-compiled single-file binary in a tar.gz, ported onto the naked base.
{ system, pins }:
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "opencode";
  version = "1.18.18";
  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v1.18.18/opencode-linux-x64.tar.gz";
    hash = "sha256-DN3CIkGLhVNmmQWomAwM2nCI8A2iTYPWrHawHJ/bKq8=";
  };
  unpack = "tar";
  binary = "opencode";
  kind = "loader";
  runtimePkgs = [ pins.ripgrep ];
  # Nix manages this binary; stop the CLI from trying to self-update. This also
  # keeps setEnv non-empty, which the wrapper writer needs: with an empty setEnv
  # its `printf | while` loop returns non-zero and, under a POSIX /bin/sh + set
  # -e, aborts wrapper generation (same failure hits any naked binary package
  # with no setEnv). The real fix belongs in mk-binary.nix.
  setEnv = {
    OPENCODE_DISABLE_AUTOUPDATE = "1";
  };
}
