# opencode2 - bun-compiled binary in an npm tarball (package/), ported onto naked.
# Reuses the repo's shared source of truth: version + hash from
# packages/opencode2/hashes.json (what nix-update bumps), url from the
# interpolated template. No duplicated, drift-prone hash.
{ system, pins }:
let
  mkBinary = import ../mk/binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "opencode2";
  hashesFile = ../../packages/opencode2/hashes.json;
  urlTemplate = "https://registry.npmjs.org/@opencode-ai/cli-linux-x64/-/cli-linux-x64-{version}.tgz";
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
