# node-bin: the upstream prebuilt nodejs tarball, no nixpkgs, no stdenv. version
# + per-system hash from ./hashes.json; per-arch platform token from systems.nix.
# node is a plain dynamic executable (no appended payload), so patchelf (via
# formatelf) is safe: set the pinned glibc interpreter + rpath.
{
  system,
  pins,
}:
let
  fetchurl = import ../../fetch/fetchurl.nix;
  mkNaked = import ../../mk/naked-sh.nix;
  sys = (import ../../systems.nix).${system};
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  inherit (data) version;
  plat = sys.node.platform;
  dir = "node-v${version}-${plat}";
  tarball = fetchurl {
    url = "https://nodejs.org/dist/v${version}/${dir}.tar.gz";
    hash = data.hashes.${system};
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
