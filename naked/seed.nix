# The bootstrap seed: two truly-static prebuilt binaries, fetched by URL, with
# zero nixpkgs. Together they are a complete build userland.
#
#   bash    - the builder. Unlike busybox it ignores argv[0], so it runs even
#             from a hash-prefixed store path (Nix always sets argv[0]=builder).
#   busybox - sh + coreutils + tar/gzip/wget in one static binary. mk-naked
#             boots its applets via `exec -a busybox` (see mk-naked.nix), since
#             busybox dispatches on argv[0] and Nix won't give it basename
#             "busybox".
#
# Both are truly static (no PT_INTERP), so they exec inside the Nix sandbox
# where no loader/libc exists yet.
let
  fetchurl = import ./fetchurl.nix;
in
{
  bash = fetchurl {
    url = "https://github.com/robxu9/bash-static/releases/download/5.2.015-1.2.3-2/bash-linux-x86_64";
    hash = "sha256-FN4KCAM7vmszXb2pUzCnQ7Di7UkMgdIrInTDQm9CaCU=";
    executable = true;
  };
  busybox = fetchurl {
    url = "https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox";
    hash = "sha256-mVOoYPn3r9NYiZjQf5AF2p7hXy1Q4kN5RSscc/PGpiY=";
    executable = true;
  };
}
