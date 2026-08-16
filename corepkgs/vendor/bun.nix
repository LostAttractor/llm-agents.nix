# Vendor a bun project's dependencies into a fixed-output derivation: `bun
# install --frozen-lockfile` from bun.lock produces node_modules, which we
# output. Like npm's vendorer it is one FOD with a committed hash (bun's
# per-package integrity hashes in bun.lock aren't a single fetchurl input).
# --ignore-scripts keeps it deterministic + compiler-free; native deps ship
# prebuilt platform binaries, which bun fetches without a build step.
{
  src,
  bunDepsHash,
  sourceRoot ? null,
  system,
  bun, # the bun toolchain, threaded from the constructor scope
}:
let
  fetchurl = import ../fetch/fetchurl.nix;
  sys = (import ../systems.nix).${system};
  busybox = fetchurl {
    inherit (sys.busybox) url hash;
    executable = true;
  };
  script = ''
    set -eu
    __bb() { ( exec -a busybox "@busybox@" "$@" ); }
    __seedbin="$NIX_BUILD_TOP/.seed-bin"
    __bb mkdir -p "$__seedbin"
    __bb --install -s "$__seedbin"
    export PATH="@bun@/bin:$__seedbin:$PATH"

    export HOME="$NIX_BUILD_TOP"
    export BUN_INSTALL="$NIX_BUILD_TOP/.bun"

    tar -xzf "$src"
    cd "$(tar -tzf "$src" | head -1 | cut -d/ -f1)"
    [ -n "$sourceRoot" ] && cd "$sourceRoot"

    bun install --frozen-lockfile --ignore-scripts --no-progress
    cp -r node_modules "$out"
  '';
in
derivation {
  name = "bun-vendor";
  inherit system src;
  sourceRoot = if sourceRoot == null then "" else sourceRoot;
  builder = "/bin/sh";
  args = [
    "-c"
    (builtins.replaceStrings [ "@busybox@" "@bun@" ] [ "${busybox}" "${bun}" ] script)
  ];
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = bunDepsHash;
}
