# The toolchain set: the compilers/runtimes corepkgs builds WITH, assembled once
# and threaded through the constructor scope - mirroring `pins`. Constructors
# receive `toolchains` and pick `toolchains.rust` etc. instead of re-importing
# ../toolchains/<x>.nix, so the toolchain a constructor uses IS the one exposed
# as corepkgs.packages.<name> (single source of truth).
#
# This is the bootstrap seam: swap this provider to change how the toolchains are
# obtained - fetched prebuilt today, built from source later (the GNU Mes
# direction) - without touching a single constructor. See [[corepkgs-bootstrap-direction]].
{ system, pins }:
let
  node = import ./node.nix { inherit system pins; };
in
{
  seed = import ../seed.nix { inherit system; };
  zig = import ./zig.nix { inherit system; };
  bun = import ./bun.nix { inherit system pins; };
  inherit node;
  # pnpm runs on the node toolchain (a JS bundle), so share the one instance
  pnpm = import ./pnpm.nix { inherit system node; };
  rust = import ./rust.nix { inherit system pins; };
  go = import ./go.nix { inherit system pins; };
}
// (
  # python's manylinux external-lib pins are x86_64-only, so it ships there only.
  if system == "x86_64-linux" then { python = import ./python.nix { inherit system pins; }; } else { }
)
