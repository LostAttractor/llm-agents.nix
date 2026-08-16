# mkGo: build a Go package from source, nixpkgs-free. CGO_ENABLED=0 -> a static
# binary, no patchelf needed. Modules vendored by vendor/go.nix (one vendorHash
# FOD; go.sum hashes aren't fetchurl-compatible). cgo = true compiles cgo C via
# zig cc -> dynamic output patchelf'd to the pinned glibc; buildInputs adds C-lib pins.
{
  pname,
  version ? null,
  src, # fetched source archive (a .tar.gz with a single top-level dir)
  vendorHash ? null, # hash of `go mod vendor` (like nixpkgs' vendorHash); null = the source commits its own in-tree vendor/ dir
  sourceRoot ? null, # subdir holding go.mod (relative to the tarball top dir)
  subPackages ? [ "." ], # package dirs to build (parallel to `binaries`)
  binaries ? [ pname ], # output binary names (parallel to `subPackages`)
  ldflags ? [ ], # extra -ldflags entries
  tags ? [ ], # -tags
  cgo ? false, # CGO_ENABLED=1: compile cgo C via zig cc; output is dynamic, patchelf'd to the pinned glibc
  buildInputs ? [ ], # C-library pins (cgo external libs) - /lib joins the rpath, /lib/pkgconfig joins PKG_CONFIG_PATH
  mainProgram ? builtins.head binaries,
  meta ? { },
  category ? null,
  updater ? null,
  system,
  pins,
  toolchains,
}:
let
  mkDrvSh = import ./drv-sh.nix;
  inherit (toolchains) go zig;
  sys = (import ../seed/systems.nix).${system};
  gnuTarget = "${sys.zig.platform}-gnu";
  extraLibPath = builtins.concatStringsSep ":" (map (p: "${p}/lib") buildInputs);
  pkgConfigPath = builtins.concatStringsSep ":" (map (p: "${p}/lib/pkgconfig") buildInputs);
  # cgo output rpath: pinned glibc + gccLib (+ any C-lib buildInputs)
  cgoLibpath =
    "${pins.glibc}/lib:${pins.gccLib}/lib" + (if extraLibPath == "" then "" else ":${extraLibPath}");
  # null vendorHash = the module has no external deps (stdlib only); skip
  # vendoring and build offline with -mod=mod.
  vendor =
    if vendorHash == null then
      null
    else
      import ../vendor/go.nix {
        inherit
          src
          vendorHash
          sourceRoot
          system
          go
          ;
      };
  # subPackages and binaries are parallel; join into "pkg:bin" pairs.
  pairs = builtins.concatStringsSep " " (
    builtins.genList (i: "${builtins.elemAt subPackages i}:${builtins.elemAt binaries i}") (
      builtins.length subPackages
    )
  );
  drv = mkDrvSh {
    inherit system;
    name = if version == null then "${pname}" else "${pname}-${version}";
    env = {
      inherit src go pairs;
      vendor = if vendor == null then "" else vendor;
      sourceRoot = if sourceRoot == null then "" else sourceRoot;
      ldflags = builtins.concatStringsSep " " ldflags;
      tags = builtins.concatStringsSep "," tags;
      useCgo = if cgo then "1" else "";
      inherit zig gnuTarget pkgConfigPath;
      cgoLibpath = if cgo then cgoLibpath else "";
      glibc = pins.glibc;
      formatelf = pins.formatelf;
      loader = sys.loader;
      pkgConfigBin = "${pins.pkgConfig}/bin";
    };
    script = ''
      export HOME="$NIX_BUILD_TOP"
      export GOPATH="$NIX_BUILD_TOP/gopath"
      export GOCACHE="$NIX_BUILD_TOP/gocache"
      export GOTOOLCHAIN=local
      export PATH="$go/bin:$PATH"

      if [ -n "$useCgo" ]; then
        # cgo: compile C via zig cc; provide zig's llvm ar/ranlib + pkg-config
        # for `#cgo pkg-config:` directives. Dynamic output, patchelf'd below.
        export CGO_ENABLED=1
        cat > "$NIX_BUILD_TOP/zcc" <<EOF
      #!/bin/sh
      filtered=
      for a in "\$@"; do
        case "\$a" in --target=*|-m64|-m32) continue ;; esac
        filtered="\$filtered \$a"
      done
      exec "$zig/bin/zig" cc -target ${gnuTarget} \$filtered
      EOF
        chmod +x "$NIX_BUILD_TOP/zcc"
        export CC="$NIX_BUILD_TOP/zcc"
        for t in ar ranlib; do
          { echo "#!/bin/sh"; echo "exec \"$zig/bin/zig\" $t \"\$@\""; } > "$NIX_BUILD_TOP/$t"
          chmod +x "$NIX_BUILD_TOP/$t"
        done
        export AR="$NIX_BUILD_TOP/ar"
        export PATH="$NIX_BUILD_TOP:$pkgConfigBin:$PATH"
        [ -n "$pkgConfigPath" ] && export PKG_CONFIG_PATH="$pkgConfigPath"
      else
        export CGO_ENABLED=0
      fi

      tar -xzf "$src"
      cd "$(tar -tzf "$src" | head -1 | cut -d/ -f1)"
      [ -n "$sourceRoot" ] && cd "$sourceRoot"

      export GOFLAGS=-mod=vendor GOPROXY=off GOSUMDB=off
      if [ -n "$vendor" ]; then
        # drop in the vendored modules (the FOD is read-only, so copy writable)
        cp -r "$vendor" vendor
        chmod -R u+w vendor
      fi
      # else: vendorHash = null - the source commits its own vendor/ dir in-tree.

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
        # cgo output is a dynamic ELF: point it at the pinned glibc + set rpath.
        if [ -n "$useCgo" ]; then
          "$formatelf/bin/formatelf" --set-interpreter "$glibc/lib/$loader" --force-rpath --set-rpath "$cgoLibpath" "$out/bin/$bin"
        fi
      done
    '';
  };
in
drv
// {
  # linux-only for now. CGO_ENABLED=0 output is static; cgo output is a dynamic
  # ELF patchelf'd to the pinned glibc.
  meta = {
    platforms = [ "x86_64-linux" ];
    inherit mainProgram;
  }
  // meta;
  passthru =
    (if category == null then { } else { inherit category; })
    // (if updater == null then { } else { inherit updater; });
  fhs = {
    kind = if cgo then "patchelf" else "static";
    libpath = if cgo then cgoLibpath else "";
    inherit mainProgram;
    ignoreMissing = "";
  };
}
// (if updater == null then { } else { inherit updater; })
