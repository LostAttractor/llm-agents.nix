# opencode2 - bun-compiled binary in an npm tarball (package/), ported onto naked.
{ system, pins }:
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "opencode2";
  version = "0.0.0-next-17444";
  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode-ai/cli-linux-x64/-/cli-linux-x64-0.0.0-next-17444.tgz";
    hash = "sha256-54iGtij74Sck19YItCjrww8PHPhBPrMbHt2d4FZzms8=";
  };
  unpack = "tar";
  binary = "package/bin/opencode2";
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
