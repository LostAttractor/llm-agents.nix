# go toolchain from the upstream prebuilt tarball (go.dev/dl), no nixpkgs, no
# stdenv. go's own binaries (go, gofmt, and the pkg/tool/* compile/link/asm/...)
# are dynamic ELFs, so patchelf every one to the pinned glibc. Note: this only
# makes the TOOLCHAIN run; a CGO_ENABLED=0 `go build` output is fully static and
# needs no patching at all (see mk/go.nix).
{
  system,
  pins,
}:
let
  fetchurl = import ../fetch/fetchurl.nix;
  mkNaked = import ../mk/naked-sh.nix;
  sys = (import ../systems.nix).${system};

  version = "1.26.6";
  tarball = fetchurl {
    url = "https://go.dev/dl/go${version}.${sys.go.platform}.tar.gz";
    hash = sys.go.hash;
  };
in
mkNaked {
  inherit system;
  name = "go-${version}";
  env = {
    inherit tarball;
    glibc = pins.glibc;
    gccLib = pins.gccLib;
    formatelf = pins.formatelf;
    loader = sys.loader;
  };
  script = ''
    tar -xzf "$tarball"
    cp -r go "$out"
    chmod -R u+w "$out"

    # patchelf every dynamic ELF in the toolchain (go/gofmt + pkg/tool/*).
    for f in $(find "$out" -type f); do
      [ "$(head -c4 "$f" | od -An -tx1 | tr -d ' \n')" = "7f454c46" ] || continue
      if "$formatelf/bin/formatelf" --print-interpreter "$f" >/dev/null 2>&1; then
        "$formatelf/bin/formatelf" --set-interpreter "$glibc/lib/$loader" --force-rpath --set-rpath "$glibc/lib:$gccLib/lib" "$f" || true
      fi
    done

    "$out/bin/go" version > "$out/go-version.txt"
  '';
}
