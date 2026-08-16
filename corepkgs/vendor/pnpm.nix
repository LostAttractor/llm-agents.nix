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
  fetchurl = import ../fetch/fetchurl.nix;
  sys = (import ../seed/systems.nix).${system};
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
    export PATH="@pnpm@/bin:@node@/bin:$__seedbin:$PATH"

    export HOME="$NIX_BUILD_TOP"

    tar -xzf "$src"
    cd "$(tar -tzf "$src" | head -1 | cut -d/ -f1)"
    [ -n "$sourceRoot" ] && cd "$sourceRoot"
    @postPatch@

    pnpm install --frozen-lockfile --ignore-scripts \
      --config.node-linker=hoisted \
      --config.store-dir="$NIX_BUILD_TOP/.pnpm-store" \
      --config.confirmModulesPurge=false

    # cp -r (NOT -L): pnpm hardlinks store files into node_modules (cp copies
    # them as real files -> self-contained), but .bin entries are RELATIVE
    # symlinks that must stay symlinks; dereferencing relocates a bin's relative
    # requires and breaks it (e.g. .bin/tsc's `import "../lib/tsc.js"`).
    cp -r node_modules "$out"
  '';
in
derivation {
  name = "pnpm-vendor";
  inherit system src;
  sourceRoot = if sourceRoot == null then "" else sourceRoot;
  builder = "/bin/sh";
  args = [
    "-c"
    (builtins.replaceStrings
      [ "@busybox@" "@pnpm@" "@node@" "@postPatch@" ]
      [ "${busybox}" "${pnpm}" "${node}" postPatch ]
      script
    )
  ];
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = pnpmDepsHash;
}
