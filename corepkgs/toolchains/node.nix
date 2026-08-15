# nodejs toolchain from the upstream prebuilt tarball, no nixpkgs, no stdenv.
# node is a plain dynamic executable (no appended payload), so patchelf (via
# formatelf) is safe: set the pinned glibc interpreter + rpath.
{
  system,
  pins,
}:
let
  fetchurl = import ../fetchurl.nix;
  mkNaked = import ../mk/naked-sh.nix;
  sys = (import ../systems.nix).${system};

  version = "22.14.0";
  plat = sys.node.platform;
  dir = "node-v${version}-${plat}";
  tarball = fetchurl {
    url = "https://nodejs.org/dist/v${version}/${dir}.tar.gz";
    hash = sys.node.hash;
  };
in
mkNaked {
  inherit system;
  name = "nodejs-${version}";
  env = {
    inherit tarball;
    glibc = pins.glibc;
    formatelf = pins.formatelf;
    gccLib = pins.gccLib;
  };
  script = ''
    tar -xzf "$tarball"
    cp -r "${dir}" "$out"
    chmod -R u+w "$out"

    "$formatelf/bin/formatelf" \
      --set-interpreter "$glibc/lib/${sys.loader}" \
      --set-rpath "$glibc/lib:$gccLib/lib" \
      "$out/bin/node"

    "$out/bin/node" --version > "$out/node-version.txt"
  '';
}
