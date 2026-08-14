# bun toolchain from the upstream prebuilt binary, no nixpkgs, no stdenv.
#
# bun must NOT be patchelf'd: it appends its JS runtime to the ELF tail and
# recomputes that offset from the on-disk file, so any ELF rewrite shifts the
# payload and segfaults it (same root cause as the bun --compile note in
# CLAUDE.md). Instead we leave the binary byte-intact and invoke the pinned
# glibc loader explicitly through a tiny wrapper.
let
  fetchurl = import ../fetchurl.nix;
  mkNaked = import ../mk-naked.nix;
  seed = import ../seed.nix;
  pinned = import ../pinned.nix;

  version = "1.3.14";
  zip = fetchurl {
    url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-x64.zip";
    hash = "sha256-lR7iruhV8IWVruxiJSJqKY0/6oOj3NZGXAnLzN9+hI8=";
  };
in
mkNaked {
  name = "bun-${version}";
  env = {
    inherit zip;
    seedBash = seed.bash;
    glibc = pinned.glibc;
    gccLib = pinned.gccLib;
  };
  script = ''
    mkdir -p "$out/libexec" "$out/bin"
    unzip -q "$zip"
    cp bun-linux-x64/bun "$out/libexec/bun"
    chmod +x "$out/libexec/bun"

    {
      echo "#!$seedBash"
      echo "exec \"$glibc/lib/ld-linux-x86-64.so.2\" --library-path \"$glibc/lib:$gccLib/lib\" \"$out/libexec/bun\" \"\$@\""
    } > "$out/bin/bun"
    chmod +x "$out/bin/bun"

    "$out/bin/bun" --version > "$out/version.txt"
  '';
}
