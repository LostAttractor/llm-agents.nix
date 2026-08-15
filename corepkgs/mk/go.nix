# mkGo: build a Go package from source, nixpkgs-free, with the naked go
# toolchain. CGO_ENABLED=0 so the output is a fully STATIC binary - no glibc, no
# patchelf, no formatelf, nothing to wrap; it just runs. Modules are vendored by
# go-vendor.nix (a single vendorHash FOD, since go.sum hashes are not
# fetchurl-compatible). CGO packages (needing a C toolchain) are out of scope for
# now.
{
  pname,
  version ? null,
  src, # fetched source archive (a .tar.gz with a single top-level dir)
  vendorHash, # hash of `go mod vendor` (like nixpkgs' vendorHash)
  sourceRoot ? null, # subdir holding go.mod (relative to the tarball top dir)
  subPackages ? [ "." ], # package dirs to build (parallel to `binaries`)
  binaries ? [ pname ], # output binary names (parallel to `subPackages`)
  ldflags ? [ ], # extra -ldflags entries
  tags ? [ ], # -tags
  mainProgram ? builtins.head binaries,
  meta ? { },
  category ? null,
  updater ? null,
  system,
  pins,
}:
let
  mkNaked = import ./naked-sh.nix;
  go = import ../toolchains/go.nix { inherit system pins; };
  vendor = import ../go-vendor.nix {
    inherit
      src
      vendorHash
      sourceRoot
      system
      pins
      ;
  };
  # subPackages and binaries are parallel; join into "pkg:bin" pairs.
  pairs = builtins.concatStringsSep " " (
    builtins.genList (i: "${builtins.elemAt subPackages i}:${builtins.elemAt binaries i}") (
      builtins.length subPackages
    )
  );
  drv = mkNaked {
    inherit system;
    name = if version == null then "${pname}-naked" else "${pname}-${version}";
    env = {
      inherit
        src
        vendor
        go
        pairs
        ;
      sourceRoot = if sourceRoot == null then "" else sourceRoot;
      ldflags = builtins.concatStringsSep " " ldflags;
      tags = builtins.concatStringsSep "," tags;
    };
    script = ''
      export HOME="$NIX_BUILD_TOP"
      export GOPATH="$NIX_BUILD_TOP/gopath"
      export GOCACHE="$NIX_BUILD_TOP/gocache"
      export GOTOOLCHAIN=local
      export GOFLAGS=-mod=vendor
      export CGO_ENABLED=0
      export PATH="$go/bin:$PATH"

      tar -xzf "$src"
      cd "$(tar -tzf "$src" | head -1 | cut -d/ -f1)"
      [ -n "$sourceRoot" ] && cd "$sourceRoot"

      # drop in the vendored modules (the FOD is read-only, so copy writable)
      cp -r "$vendor" vendor
      chmod -R u+w vendor

      mkdir -p "$out/bin"
      ldf=""
      [ -n "$ldflags" ] && ldf="-ldflags=$ldflags"
      tagf=""
      [ -n "$tags" ] && tagf="-tags=$tags"
      for pair in $pairs; do
        pkg="''${pair%%:*}"
        bin="''${pair##*:}"
        # quote $ldf/$tagf: they hold space-separated ldflags as ONE go arg
        go build ''${ldf:+"$ldf"} ''${tagf:+"$tagf"} -o "$out/bin/$bin" "./$pkg"
      done
    '';
  };
in
drv
// {
  # go source builds are linux-only for now (the naked go toolchain is Linux);
  # the output is static (no interpreter, no NEEDED), so the FHS check is trivial.
  meta = {
    platforms = [ "x86_64-linux" ];
    inherit mainProgram;
  }
  // meta;
  passthru =
    (if category == null then { } else { inherit category; })
    // (if updater == null then { } else { inherit updater; });
  fhs = {
    kind = "static";
    libpath = "";
    inherit mainProgram;
    ignoreMissing = "";
  };
}
// (if updater == null then { } else { inherit updater; })
