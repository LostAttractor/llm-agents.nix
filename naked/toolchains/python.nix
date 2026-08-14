# python toolchain from the upstream relocatable prebuilt CPython
# (astral python-build-standalone), no nixpkgs, no stdenv. Patchelf the
# interpreter to the pinned glibc; the wrapper sets LD_LIBRARY_PATH to the
# manylinux external-library set so wheels' compiled extensions resolve their
# deps (libstdc++/libz/libffi/...) at runtime, with no /usr/lib.
#
# x86_64-linux only for now (the manylinux lib pins are x86_64).
{
  system,
  pins,
}:
let
  fetchurl = import ../fetchurl.nix;
  mkNaked = import ../mk-naked-sh.nix;
  seed = import ../seed.nix { inherit system; };
  sys = (import ../systems.nix).${system};

  version = "3.12.14";
  tag = "20260814";
  tarball = fetchurl {
    url = "https://github.com/astral-sh/python-build-standalone/releases/download/${tag}/cpython-${version}%2B${tag}-x86_64-unknown-linux-gnu-install_only.tar.gz";
    hash = "sha256-MpdpGuNPdf7YGsQk4EAUX8ywuv6OWBzVytvd+hwHZsA=";
    name = "cpython-${version}.tar.gz";
  };

  # the manylinux external libraries wheels are allowed to link
  manylinux = [
    pins.glibc
    pins.gccLib
    pins.zlib
    pins.libffi
    pins.expat
    pins.ncurses
    pins.openssl
    pins.bzip2
    pins.xz
  ];
  ldpath = builtins.concatStringsSep ":" (map (p: "${p}/lib") manylinux);
in
mkNaked {
  inherit system;
  name = "python-${version}";
  env = {
    inherit tarball ldpath;
    busybox = seed.busybox;
    glibc = pins.glibc;
    formatelf = pins.formatelf;
  };
  script = ''
    tar -xzf "$tarball" # -> python/
    mkdir -p "$out"
    cp -r python "$out/py"
    chmod -R u+w "$out/py"

    # interpreter: pinned loader + DT_RPATH (its own lib for libpython/libtcl,
    # plus glibc). --force-rpath is transitive, so the stdlib .so's resolve too.
    "$formatelf/bin/formatelf" \
      --set-interpreter "$glibc/lib/${sys.loader}" \
      --force-rpath --set-rpath "$out/py/lib:$ldpath" \
      "$out/py/bin/python3.12"

    mkdir -p "$out/bin"
    ln -s "$busybox" "$out/py/sh"
    for name in python python3; do
      {
        echo "#!$out/py/sh"
        echo "export LD_LIBRARY_PATH=\"$ldpath\''${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}\""
        echo "exec \"$out/py/bin/python3.12\" \"\$@\""
      } > "$out/bin/$name"
      chmod +x "$out/bin/$name"
    done

    # smoke test: interpreter + a spread of stdlib C extensions load
    "$out/bin/python3" -c 'import ssl, ctypes, sqlite3, bz2, lzma, hashlib, zlib, curses, decimal; print("python", __import__("sys").version.split()[0], "+ stdlib C-extensions ok")' > "$out/selftest.txt"
  '';
}
