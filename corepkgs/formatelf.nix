# Dogfood: build formatelf (the ELF patcher we otherwise pin) FROM SOURCE with
# the naked rust toolchain and zig cc, using naked-vendored crates. The pinned
# formatelf post-link-patches the build's executables so they run in the
# sandbox - a one-time bootstrap seed for the naked-built one.
{
  system,
  pins,
}:
let
  fetchurl = import ./fetchurl.nix;
  mkNaked = import ./mk/naked-sh.nix;
  cargoVendor = import ./cargo-vendor.nix;
  sys = (import ./systems.nix).${system};
  rust = import ./toolchains/rust.nix { inherit system pins; };
  zig = import ./toolchains/zig.nix { inherit system; };

  gnuTarget = "${sys.zig.platform}-gnu"; # zig cc target: x86_64-linux-gnu / aarch64-linux-gnu
  rustGnu = sys.rust.gnu; # cargo [target.<triple>]

  rev = "2b36d819b48c0bfd4a084e6f0ce430633d8ee5f4";
  src = fetchurl {
    url = "https://github.com/Mic92/formatelf/archive/${rev}.tar.gz";
    hash = "sha256-2hleJRn6xsSeE8ZMotXR29z1jOY1TLf9cOOp2YDZltY=";
  };
  vendor = cargoVendor {
    cargoLock = ./packages/formatelf.Cargo.lock;
    inherit system;
  };
in
mkNaked {
  inherit system;
  name = "formatelf-naked";
  env = {
    inherit
      src
      vendor
      rust
      zig
      ;
    glibc = pins.glibc;
    gccLib = pins.gccLib;
    formatelf = pins.formatelf;
  };
  script = ''
    export HOME="$NIX_BUILD_TOP"
    export CARGO_HOME="$NIX_BUILD_TOP/.cargo"
    export ZIG_GLOBAL_CACHE_DIR="$NIX_BUILD_TOP/zig-cache"
    export PATH="$rust/bin:$zig/bin:$PATH"

    ld="$glibc/lib/${sys.loader}"
    libp="$glibc/lib:$gccLib/lib"

    # zig cc wrapper: force the glibc target (else zig falls back to musl and
    # rust's gnu std can't resolve gnu_get_libc_version/mmap64). --dynamic-linker
    # can't pass THROUGH zig (it re-sub-compiles glibc/compiler_rt inheriting the
    # flag, which they reject), so link normally then POST-LINK patch each
    # executable with the pinned formatelf - store loader + rpath so build
    # scripts run in the sandbox with no /lib64. Skip -shared (dylibs have no
    # interpreter).
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
    cd formatelf-*

    mkdir -p .cargo
    cat > .cargo/config.toml <<EOF
    [source.crates-io]
    replace-with = "vendored"
    [source.vendored]
    directory = "$vendor"
    [target.${rustGnu}]
    linker = "$NIX_BUILD_TOP/zcc"
    EOF

    cargo build --release --offline --locked

    mkdir -p "$out/bin"
    cp target/release/formatelf "$out/bin/formatelf"

    "$out/bin/formatelf" --version > "$out/selfhost.txt" 2>&1 || true
    echo "own interpreter: [$("$out/bin/formatelf" --print-interpreter "$out/bin/formatelf")]" >> "$out/selfhost.txt"
  '';
}
