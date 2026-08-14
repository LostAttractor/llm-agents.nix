# mkNakedSh: the POSIX-sh bootstrap builder (sandbox /bin/sh + busybox). Used
# only to extract nushell from its tarball; the real build logic uses mk-naked.nix
# (nushell + __structuredAttrs). Kept minimal.
# The builder is the sandbox's /bin/sh (Nix guarantees it); it boots busybox's
# applets into PATH via `exec -a busybox` (busybox dispatches on argv[0], which
# Nix hash-prefixes) then runs the build script. ~10 lines vs stdenv's ~2000.
{
  name,
  script,
  env ? { },
  system,
}:
let
  fetchurl = import ./fetchurl.nix;
  busybox = fetchurl {
    inherit ((import ./systems.nix).${system}.busybox) url hash;
    executable = true;
  };
  prelude = ''
    set -eu
    __bb() { ( exec -a busybox "@busybox@" "$@" ); }
    __seedbin="$NIX_BUILD_TOP/.seed-bin"
    __bb mkdir -p "$__seedbin"
    __bb --install -s "$__seedbin"
    export PATH="$__seedbin''${PATH:+:$PATH}"
  '';
in
derivation (
  env
  // {
    inherit name system;
    builder = "/bin/sh";
    args = [
      "-c"
      (builtins.replaceStrings [ "@busybox@" ] [ "${busybox}" ] (prelude + "\n" + script))
    ];
  }
)
