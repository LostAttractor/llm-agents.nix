# Naked build layer: packages with no nixpkgs, no stdenv. Standalone entrypoint
# with storePath pins (fast eval, impure). Build with:
#   nix build -f naked <attr>              (x86_64-linux toolchains + packages)
#   nix build -f naked aarch64-linux.bun   (another system, via the table)
#
# nixbot builds the pure/flake variant instead (see naked/flake.nix); here the
# storePath pins keep eval at ~0.05s but can't be used from a flake.
let
  build = import ./build.nix;
  pinsStore = import ./pins-store.nix;
  x = pinsStore "x86_64-linux";
in
(build.toolchains {
  system = "x86_64-linux";
  pins = x;
})
// (build.packages x)
// {
  checks = build.checks x (build.packages x);

  # per-system toolchain sets
  x86_64-linux = build.toolchains {
    system = "x86_64-linux";
    pins = x;
  };
  aarch64-linux = build.toolchains {
    system = "aarch64-linux";
    pins = pinsStore "aarch64-linux";
  };
}
