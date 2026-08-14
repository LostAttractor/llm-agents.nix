# nodejs toolchain from the upstream prebuilt tarball, no nixpkgs, no stdenv.
# node is a plain dynamic executable (no appended payload), so patchelf is safe
# here - set the pinned glibc interpreter + rpath (glibc + libstdc++).
let
  fetchurl = import ../fetchurl.nix;
  mkNaked = import ../mk-naked.nix;
  pinned = import ../pinned.nix;

  version = "22.14.0";
  tarball = fetchurl {
    url = "https://nodejs.org/dist/v${version}/node-v${version}-linux-x64.tar.gz";
    hash = "sha256-nZQpMlNZiAkQNNyUzF9CttyHhNY2bfOjbEycyzmW8MI=";
  };
in
mkNaked {
  name = "nodejs-${version}";
  env = {
    inherit tarball;
    glibc = pinned.glibc;
    patchelf = pinned.patchelf;
    gccLib = pinned.gccLib;
  };
  script = ''
    tar -xzf "$tarball"
    cp -r "node-v${version}-linux-x64" "$out"
    chmod -R u+w "$out"

    "$patchelf/bin/patchelf" \
      --set-interpreter "$glibc/lib/ld-linux-x86-64.so.2" \
      --set-rpath "$glibc/lib:$gccLib/lib" \
      "$out/bin/node"

    "$out/bin/node" --version > "$out/node-version.txt"
  '';
}
