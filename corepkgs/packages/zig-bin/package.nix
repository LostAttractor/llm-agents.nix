# zig-bin: the upstream prebuilt zig tarball, no nixpkgs, no stdenv, and -
# uniquely - no glibc pin: the zig binary is truly static, and `zig cc` is a
# complete self-contained C/C++ compiler + linker + libc. version + per-system
# hash from ./hashes.json; per-arch platform token from systems.nix.
{
  system,
}:
let
  fetchurl = import ../../fetch/fetchurl.nix;
  mkNaked = import ../../mk/naked-sh.nix;
  seed = import ../../seed { inherit system; };
  sys = (import ../../seed/systems.nix).${system};
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  inherit (data) version;
  plat = sys.zig.platform; # e.g. x86_64-linux / aarch64-linux
  muslTarget = "${plat}-musl"; # zig cc target: x86_64-linux-musl / aarch64-linux-musl
  tarball = fetchurl {
    url = "https://ziglang.org/download/${version}/zig-${plat}-${version}.tar.xz";
    hash = data.hashes.${system};
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
