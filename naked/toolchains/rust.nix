# rust toolchain from upstream prebuilt components, no nixpkgs, no stdenv.
# Merge rustc + cargo + rust-std into one prefix, then patchelf every ELF:
# executables get the glibc interpreter, and every binary/.so gets an rpath
# covering our own lib (librustc_driver, libLLVM, libstd find each other) plus
# the pinned glibc/libstdc++. rustc uses DT_RUNPATH (non-transitive), so the
# libraries must be patched too, not just the executables.
let
  fetchurl = import ../fetchurl.nix;
  mkNaked = import ../mk-naked.nix;
  pinned = import ../pinned.nix;

  version = "1.83.0";
  triple = "x86_64-unknown-linux-gnu";
  comp = name: hash: fetchurl {
    url = "https://static.rust-lang.org/dist/${name}-${version}-${triple}.tar.gz";
    inherit hash;
  };
  # musl std, so rustc --target x86_64-unknown-linux-musl can emit fully static
  # binaries (linked by zig cc), which need no glibc at all.
  muslStd = fetchurl {
    url = "https://static.rust-lang.org/dist/rust-std-${version}-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-HAQ23gjeZBnSn6935cmDH2Tpw2mJJ2nfqkx+1BHFjRo=";
  };
in
mkNaked {
  name = "rust-${version}";
  env = {
    rustc = comp "rustc" "sha256-V06zNWd7/6iOWyNROcd4TPEjRki7z4sPk8cSQBOGiRE=";
    cargo = comp "cargo" "sha256-WGvVjnaBsJ/9yVGRuqlds/fADXOfnLFaYMQP2t4k/d8=";
    ruststd = comp "rust-std" "sha256-XMozMPcT+nJ521OEiQwmZTXQeahc39GlLmnFXykducQ=";
    inherit muslStd;
    glibc = pinned.glibc;
    patchelf = pinned.patchelf;
    gccLib = pinned.gccLib;
    zlib = pinned.zlib;
    zstd = pinned.zstd;
  };
  script = ''
    tar -xzf "$rustc"
    tar -xzf "$cargo"
    tar -xzf "$ruststd"

    mkdir -p "$out"
    cp -r "rustc-${version}-${triple}/rustc/." "$out/"
    cp -r "cargo-${version}-${triple}/cargo/." "$out/"
    cp -r "rust-std-${version}-${triple}/rust-std-${triple}/." "$out/"
    tar -xzf "$muslStd"
    cp -r "rust-std-${version}-x86_64-unknown-linux-musl/rust-std-x86_64-unknown-linux-musl/." "$out/"
    chmod -R u+w "$out"

    RPATH="$out/lib:$glibc/lib:$gccLib/lib:$zlib/lib:$zstd/lib"
    for exe in "$out/bin/rustc" "$out/bin/cargo"; do
      "$patchelf/bin/patchelf" --set-interpreter "$glibc/lib/ld-linux-x86-64.so.2" --set-rpath "$RPATH" "$exe"
    done
    for so in $(find "$out/lib" -name '*.so*' -type f); do
      "$patchelf/bin/patchelf" --set-rpath "$RPATH" "$so" || true
    done

    "$out/bin/rustc" --version > "$out/rustc-version.txt"
    "$out/bin/cargo" --version > "$out/cargo-version.txt"
  '';
}
