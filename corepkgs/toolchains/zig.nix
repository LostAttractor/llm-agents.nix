# zig toolchain from the upstream prebuilt tarball, no nixpkgs, no stdenv, and -
# uniquely - no glibc pin: the zig binary is truly static, and `zig cc` is a
# complete self-contained C/C++ compiler + linker + libc that emits fully
# static musl binaries. The missing "last mile" C toolchain, zero nixpkgs.
{
  system,
}:
let
  fetchurl = import ../fetchurl.nix;
  mkNaked = import ../mk/naked-sh.nix;
  seed = import ../seed.nix { inherit system; };
  sys = (import ../systems.nix).${system};

  version = "0.16.0";
  plat = sys.zig.platform; # e.g. x86_64-linux / aarch64-linux
  muslTarget = "${plat}-musl"; # zig cc target: x86_64-linux-musl / aarch64-linux-musl
  tarball = fetchurl {
    url = "https://ziglang.org/download/${version}/zig-${plat}-${version}.tar.xz";
    hash = sys.zig.hash;
  };
in
mkNaked {
  inherit system;
  name = "zig-${version}";
  env = {
    inherit tarball;
    busybox = seed.busybox;
  };
  script = ''
    tar -xf "$tarball"
    cp -r "zig-${plat}-${version}" "$out"
    chmod -R u+w "$out"
    mkdir -p "$out/bin"
    ln -s ../zig "$out/bin/zig"

    ln -s "$busybox" "$out/bin/sh"
    for tool in cc c++; do
      {
        echo "#!$out/bin/sh"
        echo "exec \"$out/zig\" $tool \"\$@\""
      } > "$out/bin/$tool"
      chmod +x "$out/bin/$tool"
    done

    export ZIG_GLOBAL_CACHE_DIR="$NIX_BUILD_TOP/zig-cache"
    printf '#include <stdio.h>\nint main(){printf("zig cc ok\\n");return 0;}\n' > t.c
    "$out/bin/cc" -target ${muslTarget} -o t.out t.c
    ./t.out > "$out/selftest.txt"
    "$out/bin/zig" version >> "$out/selftest.txt"
  '';
}
