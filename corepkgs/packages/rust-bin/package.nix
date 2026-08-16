# rust-bin: upstream prebuilt rust components (rustc + cargo + rust-std gnu +
# musl), no nixpkgs, no stdenv. version + per-system component hashes from
# ./hashes.json; the target triples (gnu/musl, used by mkCargo too) stay in
# systems.nix. Merge into one prefix, then formatelf every ELF: exes get the
# pinned glibc interpreter + a transitive DT_RPATH, .so's get their stale
# DT_RUNPATH stripped.
{
  system,
  pins,
}:
let
  fetchurl = import ../../fetch/fetchurl.nix;
  mkDrvSh = import ../../mk/drv-sh.nix;
  sys = (import ../../seed/systems.nix).${system};
  data = builtins.fromJSON (builtins.readFile ./hashes.json);
  h = data.hashes.${system};

  inherit (data) version;
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
    hash = h.muslStd;
  };
in
mkDrvSh {
  inherit system;
  name = "rust-${version}";
  env = {
    rustc = comp "rustc" h.rustc;
    cargo = comp "cargo" h.cargo;
    ruststd = comp "rust-std" h.std;
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
