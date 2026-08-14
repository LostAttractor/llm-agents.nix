# The bootstrap seed for a given system: one truly-static prebuilt busybox
# (sh + coreutils + tar/gzip/xz/unzip), fetched by URL from the per-system
# table, zero nixpkgs. The build *builder* is the sandbox's /bin/sh (see
# mk-naked.nix), so we don't fetch a shell. busybox is truly static (no
# PT_INTERP) so it execs in the sandbox before any loader/libc exists.
{
  system,
}:
let
  fetchurl = import ./fetchurl.nix;
  sys = (import ./systems.nix).${system};
in
{
  busybox = fetchurl {
    inherit (sys.busybox) url hash;
    executable = true;
  };
}
