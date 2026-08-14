# Flake entrypoint for the naked layer: PURE pins sourced from `pkgs`, so this
# is a valid flake output that nixbot can build on the real per-arch builders.
# Returns a FLAT attrset of derivations (toolchains + x86_64 packages +
# check-<pkg>), which the repo flake exposes as checks.<system>.naked-<name>.
pkgs:
let
  lib = pkgs.lib;
  build = import ./build.nix;
  pins = (import ./pins-pkgs.nix) pkgs;
  system = pkgs.stdenv.hostPlatform.system;

  toolchains = build.toolchains { inherit system pins; };
  # python is x86_64-only (manylinux lib pins are x86_64)
  extra = if system == "x86_64-linux" then { python = build.python pins; } else { };
  pkgSet = if system == "x86_64-linux" then build.packages pins else { };
  checks = if system == "x86_64-linux" then build.checks pins pkgSet else { };
in
lib.filterAttrs (_: lib.isDerivation) (
  toolchains // extra // pkgSet // lib.mapAttrs' (n: v: lib.nameValuePair "check-${n}" v) checks
)
