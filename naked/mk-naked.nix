# mkNaked: build a derivation with no nixpkgs and no stdenv. The builder is the
# static seed bash; the first thing it does is install busybox's applets into
# PATH so the user's build script has sh-level coreutils.
#
# This is the whole "mkDerivation replacement" — a few lines instead of the
# ~2000-line nixpkgs generic builder, because we only support what our packages
# actually do: fetch, unpack, patch, install.
let
  seed = import ./seed.nix;

  # Boot busybox applets, then run the user script. busybox dispatches on
  # argv[0]; Nix hands the builder a hash-prefixed argv[0], so we force
  # argv[0]="busybox" via bash's `exec -a` inside a subshell for each call, use
  # that to `--install` all applets into a bin dir, then put it on PATH.
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
  # extra key=value env vars for the build
  env ? { },
  system ? "x86_64-linux",
}:
derivation (
  env
  // {
    inherit name system;
    builder = seed.bash;
    args = [
      "-c"
      # substitute @busybox@ with the seed path (a store-path reference, so Nix
      # tracks busybox as an input and mounts it in the sandbox)
      (builtins.replaceStrings [ "@busybox@" ] [ "${seed.busybox}" ] (prelude + "\n" + script))
    ];
  }
)
