# Pin provider for standalone `nix build -f naked`: the tools referenced via
# builtins.storePath, so eval touches zero nixpkgs (the ~20x eval win). IMPURE
# (storePath) - not usable from a flake; the flake uses pins-pkgs.nix instead.
#
# These are stock nixpkgs outputs (glibc/gccLib/zlib/zstd, in cache.nixos.org)
# plus this repo's formatelf (numtide cache). Regenerate on a nixpkgs bump.
system:
{
  x86_64-linux = {
    glibc = builtins.storePath /nix/store/0d8g8n0a11v6f5m2h416ajyxmnkwc3md-glibc-2.42-67;
    gccLib = builtins.storePath /nix/store/r48746qznwqxxl9qzd8f08ny8mg1dg2y-gcc-15.3.0-lib;
    zlib = builtins.storePath /nix/store/zks9mfsn4rqr6z9g6pcj2xqzcsplj0nb-zlib-1.3.2;
    zstd = builtins.storePath /nix/store/pxahscw9vl9vac1nbjpy6bhz3vbk3cpl-zstd-1.5.7;
    formatelf = builtins.storePath /nix/store/r6a970q9v1bzdfrd8dcqjmnfs94lh45g-formatelf-0-unstable-2026-08-11;
  };
  aarch64-linux = {
    glibc = builtins.storePath /nix/store/f8q4w2hbjvwy7qqwpnvbf5f4qwyww6cp-glibc-2.42-67;
    gccLib = builtins.storePath /nix/store/ylzalvsf8nxhidm1p72k6ckxckpj1wd3-gcc-15.3.0-lib;
    zlib = builtins.storePath /nix/store/3v2w5hdrpzwx3w8svda35lyrq9jwqbc8-zlib-1.3.2;
    zstd = builtins.storePath /nix/store/k2fr8pihnym47m71fij3ns184vbx4v79-zstd-1.5.7;
    formatelf = builtins.storePath /nix/store/hk6nkaqbxlyymm91gw9v3rr5b88z0mqy-formatelf-0-unstable-2026-08-11;
  };
}
.${system}
