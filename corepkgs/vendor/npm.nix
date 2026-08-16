# Vendor an npm package's dependencies into a fixed-output derivation: `npm ci`
# from package-lock.json produces node_modules, which we output. Like nixpkgs'
# npmDepsHash it is one FOD with a committed hash (npm's own integrity hashes in
# package-lock.json aren't a single fetchurl input). --ignore-scripts keeps it
# deterministic + compiler-free (native-module packages are out of scope).
{
  src,
  npmDepsHash,
  sourceRoot ? null,
  packageLock ? null, # inject a committed package-lock.json (for registry tarballs that ship none, like nixpkgs' runCommand-injected lock)
  omitOptional ? false, # `npm ci --omit=optional`: drop optionalDependencies (cross-platform prebuilds a package ships but does not need). NOT the default: many packages get their one platform-correct native binding via an optionalDependency.
  system,
  node, # the node toolchain, threaded from the constructor scope
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
    export PATH="@node@/bin:$__seedbin:$PATH"

    export HOME="$NIX_BUILD_TOP"
    export npm_config_cache="$NIX_BUILD_TOP/.npm"
    export npm_config_update_notifier=false
    export npm_config_fund=false
    export npm_config_audit=false

    tar -xzf "$src"
    cd "$(tar -tzf "$src" | head -1 | cut -d/ -f1)"
    [ -n "$sourceRoot" ] && cd "$sourceRoot"

    [ -n "$packageLock" ] && cp "$packageLock" package-lock.json
    npm ci --ignore-scripts --no-audit --no-fund $omitFlag
    cp -r node_modules "$out"
  '';
in
derivation {
  name = "npm-vendor";
  inherit system src;
  sourceRoot = if sourceRoot == null then "" else sourceRoot;
  packageLock = if packageLock == null then "" else packageLock;
  omitFlag = if omitOptional then "--omit=optional" else "";
  builder = "/bin/sh";
  args = [
    "-c"
    (builtins.replaceStrings [ "@busybox@" "@node@" ] [ "${busybox}" "${node}" ] script)
  ];
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = npmDepsHash;
}
