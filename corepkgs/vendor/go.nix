# Vendor a go module's deps as ONE fixed-output derivation: `go mod vendor` runs
# with network, caller commits the hash. go.sum records h1: tree hashes, not
# fetchurl-compatible, so unlike cargo we can't do per-dep FODs. Deterministic
# given go.sum.
{
  src,
  vendorHash,
  sourceRoot ? null,
  system,
  go, # the go toolchain, threaded from the constructor scope
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
    export PATH="@go@/bin:$__seedbin:$PATH"

    export HOME="$NIX_BUILD_TOP"
    export GOPATH="$NIX_BUILD_TOP/gopath"
    export GOMODCACHE="$GOPATH/pkg/mod"
    export GOCACHE="$NIX_BUILD_TOP/gocache"
    export GOTOOLCHAIN=local
    export GOFLAGS=-mod=mod

    tar -xzf "$src"
    cd "$(tar -tzf "$src" | head -1 | cut -d/ -f1)"
    [ -n "$sourceRoot" ] && cd "$sourceRoot"

    go mod vendor
    cp -r vendor "$out"
  '';
in
derivation {
  name = "go-vendor";
  inherit system src;
  sourceRoot = if sourceRoot == null then "" else sourceRoot;
  builder = "/bin/sh";
  args = [
    "-c"
    (builtins.replaceStrings [ "@busybox@" "@go@" ] [ "${busybox}" "${go}" ] script)
  ];
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = vendorHash;
}
