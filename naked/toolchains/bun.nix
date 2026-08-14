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
  # A runtime shell for the wrapper: busybox reached through a symlink named
  # "sh" (busybox dispatches on argv[0], and the shebang passes the symlink
  # path, so basename "sh" runs the sh applet). Avoids fetching a second shell.

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
    busybox = seed.busybox;
    glibc = pinned.glibc;
    gccLib = pinned.gccLib;
  };
  script = ''
    mkdir -p "$out/libexec" "$out/bin"
    unzip -q "$zip"
    cp bun-linux-x64/bun "$out/libexec/bun"
    chmod +x "$out/libexec/bun"

    # runtime shell: busybox via a symlink named "sh"
    ln -s "$busybox" "$out/libexec/sh"
    {
      echo "#!$out/libexec/sh"
      echo "exec \"$glibc/lib/ld-linux-x86-64.so.2\" --library-path \"$glibc/lib:$gccLib/lib\" \"$out/libexec/bun\" \"\$@\""
    } > "$out/bin/bun"
    chmod +x "$out/bin/bun"

    "$out/bin/bun" --version > "$out/version.txt"
  '';
}
