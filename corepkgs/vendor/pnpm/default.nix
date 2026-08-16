# Vendor a pnpm project's deps as ONE fixed-output derivation. pnpm's default
# layout is a symlink farm into a CA store outside node_modules; force
# `--config.node-linker=hoisted` so node_modules is a flat self-contained tree
# we can output and hash directly. --ignore-scripts keeps it compiler-free.
{
  src,
  pnpmDepsHash,
  sourceRoot ? null,
  postPatch ? "",
  system,
  pnpm, # pnpm toolchain
  node, # node toolchain (pnpm shells out to node)
}:
let
  mkDrvSh = import ../../mk/drv-sh.nix;
in
mkDrvSh {
  inherit system;
  name = "pnpm-vendor";
  outputHash = pnpmDepsHash;
  env = {
    inherit src postPatch;
    sourceRoot = if sourceRoot == null then "" else sourceRoot;
    pnpm = "${pnpm}";
    node = "${node}";
  };
  script = ./builder.sh;
}
