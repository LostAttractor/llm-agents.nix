# rust toolchain from upstream prebuilt components, no nixpkgs, no stdenv.
# Merge rustc + cargo + rust-std (gnu + musl) into one prefix, then formatelf
# every ELF: exes get the pinned glibc interpreter + a DT_RPATH (via
# --force-rpath, searched transitively so it also resolves librustc_driver/
# libLLVM/libstd deps), and the .so's just get their stale DT_RUNPATH stripped.
{
  system,
  pins,
}:
let
  fetchurl = import ../fetchurl.nix;
  mkNaked = import ../mk-naked-sh.nix;
  sys = (import ../systems.nix).${system};

  version = "1.90.0";
  gnu = sys.rust.gnu;
  musl = sys.rust.musl;
  comp =
    name: hash:
    fetchurl {
      url = "https://static.rust-lang.org/dist/${name}-${version}-${gnu}.tar.gz";
      inherit hash;
    };
  muslStd = fetchurl {
    url = "https://static.rust-lang.org/dist/rust-std-${version}-${musl}.tar.gz";
    hash = sys.rust.muslStd;
  };
in
mkNaked {
  inherit system;
  name = "rust-${version}";
  env = {
    rustc = comp "rustc" sys.rust.rustc;
    cargo = comp "cargo" sys.rust.cargo;
    ruststd = comp "rust-std" sys.rust.std;
    inherit muslStd;
    glibc = pins.glibc;
    formatelf = pins.formatelf;
    gccLib = pins.gccLib;
    zlib = pins.zlib;
    zstd = pins.zstd;
  };
  script = ''
    tar -xzf "$rustc"
    tar -xzf "$cargo"
    tar -xzf "$ruststd"

    mkdir -p "$out"
    cp -r "rustc-${version}-${gnu}/rustc/." "$out/"
    cp -r "cargo-${version}-${gnu}/cargo/." "$out/"
    cp -r "rust-std-${version}-${gnu}/rust-std-${gnu}/." "$out/"
    tar -xzf "$muslStd"
    cp -r "rust-std-${version}-${musl}/rust-std-${musl}/." "$out/"
    chmod -R u+w "$out"

    RPATH="$out/lib:$glibc/lib:$gccLib/lib:$zlib/lib:$zstd/lib"
    for exe in "$out/bin/rustc" "$out/bin/cargo"; do
      "$formatelf/bin/formatelf" --set-interpreter "$glibc/lib/${sys.loader}" --force-rpath --set-rpath "$RPATH" "$exe"
    done
    # only real ELF objects: some *.so* files (musl self-contained stubs) are
    # linker scripts, which formatelf rejects rather than ignoring.
    for so in $(find "$out/lib" -name '*.so*' -type f); do
      [ "$(head -c4 "$so" | od -An -tx1 | tr -d ' \n')" = "7f454c46" ] || continue
      "$formatelf/bin/formatelf" --remove-rpath "$so" || true
    done

    "$out/bin/rustc" --version > "$out/rustc-version.txt"
    "$out/bin/cargo" --version > "$out/cargo-version.txt"
  '';
}
