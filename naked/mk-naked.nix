# mkNaked: build a derivation with no nixpkgs and no stdenv. The builder is the
# sandbox's /bin/sh (Nix guarantees it); the first thing it does is install
# busybox's applets into PATH so the build script has sh-level coreutils.
#
# This is the whole "mkDerivation replacement" - a few lines instead of the
# ~2000-line nixpkgs generic builder, because we only support what our packages
# actually do: fetch, unpack, patch, install.
let
  seed = import ./seed.nix;

  # Boot busybox applets, then run the user script. busybox dispatches on
  # argv[0]; we force argv[0]="busybox" via `exec -a` in a subshell to
  # `--install` every applet into a bin dir, then put it on PATH.
  prelude = ''
    set -eu
    __bb() { ( exec -a busybox "@busybox@" "$@" ); }
    __seedbin="$NIX_BUILD_TOP/.seed-bin"
    __bb mkdir -p "$__seedbin"
    __bb --install -s "$__seedbin"
    export PATH="$__seedbin''${PATH:+:$PATH}"
  '';
in
{
  name,
  script,
  env ? { },
  system ? "x86_64-linux",
}:
derivation (
  env
  // {
    inherit name system;
    builder = "/bin/sh";
    args = [
      "-c"
      # substitute @busybox@ with the seed path (a store-path reference, so Nix
      # tracks busybox as an input and mounts it in the sandbox)
      (builtins.replaceStrings [ "@busybox@" ] [ "${seed.busybox}" ] (prelude + "\n" + script))
    ];
  }
)
