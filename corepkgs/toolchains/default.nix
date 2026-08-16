# The toolchain set: compilers/runtimes corepkgs builds WITH, threaded through the
# constructor scope like `pins`. Single source of truth - the toolchain a
# constructor picks (toolchains.rust) IS the one exposed as packages.<name>.
# Bootstrap seam: swap this provider (prebuilt today, GNU Mes from-source later)
# without touching a constructor. See [[corepkgs-bootstrap-direction]].
{ system, pins }:
let
  node = import ../packages/node-bin/package.nix { inherit system pins; };
in
{
  seed = import ../seed { inherit system; };
  zig = import ../packages/zig-bin/package.nix { inherit system; };
  bun = import ../packages/bun-bin/package.nix { inherit system pins; };
  inherit node;
  # pnpm runs on the node toolchain (a JS bundle), so share the one instance
  pnpm = import ../packages/pnpm-bin/package.nix { inherit system node; };
  rust = import ../packages/rust-bin/package.nix { inherit system pins; };
  go = import ../packages/go-bin/package.nix { inherit system pins; };
}
// (
  # python's manylinux external-lib pins are x86_64-only, so it ships there only.
  if system == "x86_64-linux" then
    { python = import ../packages/python-bin/package.nix { inherit system pins; }; }
  else
    { }
)
