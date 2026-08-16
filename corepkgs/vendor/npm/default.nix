# Vendor an npm package's deps as ONE fixed-output derivation: `npm ci` from
# package-lock.json produces node_modules, which we output. npm's integrity
# hashes aren't a single fetchurl input, so it's one committed-hash FOD.
# --ignore-scripts keeps it deterministic + compiler-free (no native modules).
{
  src,
  npmDepsHash,
  sourceRoot ? null,
  packageLock ? null, # inject a committed package-lock.json (for registry tarballs that ship none)
  omitOptional ? false, # npm ci --omit=optional: drop optionalDependencies. NOT default: many packages get their platform-correct native binding via an optionalDependency.
  system,
  node, # the node toolchain, threaded from the constructor scope
}:
let
  mkDrvSh = import ../../mk/drv-sh.nix;
in
mkDrvSh {
  inherit system;
  name = "npm-vendor";
  outputHash = npmDepsHash;
  env = {
    inherit src;
    sourceRoot = if sourceRoot == null then "" else sourceRoot;
    packageLock = if packageLock == null then "" else packageLock;
    omitFlag = if omitOptional then "--omit=optional" else "";
    node = "${node}";
  };
  script = ./builder.sh;
}
