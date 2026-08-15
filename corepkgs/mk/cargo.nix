# mkCargo: build a Rust package from source, nixpkgs-free, with the naked rust
# toolchain + `zig cc` as the linker + crates vendored by cargo-vendor.nix.
#
# zig cc can't be handed --dynamic-linker (it re-sub-compiles glibc/compiler_rt
# inheriting the flag, which they reject), so we link normally and POST-LINK
# patch each produced executable with the pinned formatelf: store loader + rpath,
# so build scripts and the final binaries run in the sandbox with no /lib64.
#
# Scope: this handles packages whose Cargo.lock is pure crates.io and that need
# no external C libraries. C-dep crates (-sys: openssl/sqlite/...) and git
# dependencies are NOT handled yet - they need C-lib pins + pkg-config, and a
# git-source vendorer, respectively.
{
  pname,
  version ? null,
  src, # fetched source archive (a .tar.gz with a single top-level dir)
  cargoLock, # path to the package's Cargo.lock
  binaries ? [ pname ], # binaries to install from target/release/
  cargoBuildFlags ? [ ], # e.g. [ "--no-default-features" "--features" "x" "-p" "sub" ]
  system,
  pins,
}:
let
  mkNaked = import ./naked-sh.nix;
  cargoVendor = import ../cargo-vendor.nix;
  sys = (import ../systems.nix).${system};
  rust = import ../toolchains/rust.nix { inherit system pins; };
  zig = import ../toolchains/zig.nix { inherit system; };

  gnuTarget = "${sys.zig.platform}-gnu"; # zig cc target
  rustGnu = sys.rust.gnu; # cargo [target.<triple>]
  vendor = cargoVendor { inherit cargoLock system; };
in
mkNaked {
  inherit system;
  name = if version == null then "${pname}-naked" else "${pname}-${version}";
  env = {
    inherit
      src
      vendor
      rust
      zig
      rustGnu
      gnuTarget
      ;
    installBins = builtins.concatStringsSep " " binaries;
    buildFlags = builtins.concatStringsSep " " cargoBuildFlags;
    glibc = pins.glibc;
    gccLib = pins.gccLib;
    formatelf = pins.formatelf;
    loader = sys.loader;
  };
  script = ''
    export HOME="$NIX_BUILD_TOP"
    export CARGO_HOME="$NIX_BUILD_TOP/.cargo"
    export ZIG_GLOBAL_CACHE_DIR="$NIX_BUILD_TOP/zig-cache"
    export PATH="$rust/bin:$zig/bin:$PATH"

    ld="$glibc/lib/$loader"
    libp="$glibc/lib:$gccLib/lib"

    # zig cc wrapper: force the glibc target (else zig falls back to musl and
    # rust's gnu std can't resolve gnu_get_libc_version/mmap64), then POST-LINK
    # patch each produced executable with the pinned formatelf (skip -shared:
    # dylibs have no interpreter).
    cat > "$NIX_BUILD_TOP/zcc" <<EOF
    #!/bin/sh
    "$zig/bin/zig" cc -target ${gnuTarget} "\$@" || exit \$?
    shared=0; out=""; prev=""
    for a in "\$@"; do
      [ "\$a" = "-shared" ] && shared=1
      [ "\$prev" = "-o" ] && out="\$a"
      prev="\$a"
    done
    if [ "\$shared" -eq 0 ] && [ -n "\$out" ] && [ -f "\$out" ]; then
      "$formatelf/bin/formatelf" --set-interpreter "$ld" --force-rpath --set-rpath "$libp" "\$out" 2>/dev/null || true
    fi
    EOF
    chmod +x "$NIX_BUILD_TOP/zcc"
    export CC="$NIX_BUILD_TOP/zcc"

    tar -xzf "$src"
    cd "$(tar -tzf "$src" | head -1 | cut -d/ -f1)"

    mkdir -p .cargo
    cat > .cargo/config.toml <<EOF
    [source.crates-io]
    replace-with = "vendored"
    [source.vendored]
    directory = "$vendor"
    [target.${rustGnu}]
    linker = "$NIX_BUILD_TOP/zcc"
    EOF

    cargo build --release --offline --locked $buildFlags

    mkdir -p "$out/bin"
    for b in $installBins; do
      cp "target/release/$b" "$out/bin/$b"
    done
  '';
}
