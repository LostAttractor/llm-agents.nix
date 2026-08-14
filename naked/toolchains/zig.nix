# zig toolchain from the upstream prebuilt tarball, no nixpkgs, no stdenv, and -
# uniquely - no glibc pin: the zig binary is truly static (no PT_INTERP), and
# `zig cc` is a complete self-contained C/C++ compiler + linker + libc. It can
# emit fully static musl binaries that depend on nothing.
#
# This is the missing "last mile": a C toolchain for linking (rust executables,
# node native addons) that needs zero nixpkgs.
let
  fetchurl = import ../fetchurl.nix;
  mkNaked = import ../mk-naked.nix;
  seed = import ../seed.nix;

  version = "0.16.0";
  tarball = fetchurl {
    url = "https://ziglang.org/download/${version}/zig-x86_64-linux-${version}.tar.xz";
    hash = "sha256-cOSWZKdDdLSLUebz/fv0N/Y5XUJQkFBYi9SavlK6PQA=";
  };
in
mkNaked {
  name = "zig-${version}";
  env = {
    inherit tarball;
    busybox = seed.busybox;
  };
  script = ''
    tar -xf "$tarball"
    cp -r "zig-x86_64-linux-${version}" "$out"
    chmod -R u+w "$out"
    mkdir -p "$out/bin"
    ln -s ../zig "$out/bin/zig"

    # cc / c++ wrappers (busybox reached via a symlink named sh, for the shebang)
    ln -s "$busybox" "$out/bin/sh"
    for tool in cc c++; do
      {
        echo "#!$out/bin/sh"
        echo "exec \"$out/zig\" $tool \"\$@\""
      } > "$out/bin/$tool"
      chmod +x "$out/bin/$tool"
    done

    # self-test: compile + link a fully static C binary and run it
    export ZIG_GLOBAL_CACHE_DIR="$NIX_BUILD_TOP/zig-cache"
    printf '#include <stdio.h>\nint main(){printf("zig cc ok\\n");return 0;}\n' > t.c
    "$out/bin/cc" -target x86_64-linux-musl -o t.out t.c
    ./t.out > "$out/selftest.txt"
    "$out/bin/zig" version >> "$out/selftest.txt"
  '';
}
