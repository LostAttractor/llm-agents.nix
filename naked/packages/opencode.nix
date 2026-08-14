# opencode - bun-compiled single-file binary in a tar.gz, ported onto the naked
# base. Reuses the repo's shared source of truth: version + hash from
# packages/opencode/hashes.json (what nix-update bumps), url from the
# interpolated template. No duplicated, drift-prone hash.
{ system, pins }:
let
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "opencode";
  hashesFile = ../../packages/opencode/hashes.json;
  urlTemplate = "https://github.com/anomalyco/opencode/releases/download/v{version}/opencode-linux-x64.tar.gz";
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
