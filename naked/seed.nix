# The bootstrap seed: one truly-static prebuilt binary, fetched by URL, zero
# nixpkgs. busybox is a complete build userland (sh + coreutils + tar/gzip/xz/
# unzip). The build *builder* is the sandbox's own /bin/sh (Nix provides it in
# every sandbox), so we don't even fetch a shell - see mk-naked.nix.
#
# busybox is truly static (no PT_INTERP), so it execs in the sandbox where no
# loader/libc exists yet. mk-naked boots its applets via `exec -a busybox`,
# since busybox dispatches on argv[0] and a hash-prefixed store path isn't
# basename "busybox".
let
  fetchurl = import ./fetchurl.nix;
in
{
  busybox = fetchurl {
    url = "https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox";
    hash = "sha256-mVOoYPn3r9NYiZjQf5AF2p7hXy1Q4kN5RSscc/PGpiY=";
    executable = true;
  };
}
