# The nixpkgs boundary.
#
# The seed userland (seed.nix) is 100% nixpkgs-free. But prebuilt toolchains
# (bun, node, rust) are dynamically linked to glibc, and the Nix sandbox has no
# loader. Fixing that needs glibc + an ELF patcher. Bootstrapping glibc from
# source is rebuilding stdenv, which is the whole point we are avoiding - so
# instead we PIN these tools by store path.
#
# The ELF patcher is `formatelf` (Mic92's Rust patchelf replacement) - the same
# tool this repo already uses as its auto-patchelf hook, not stock patchelf - so
# the naked layer matches the rest of the repo.
#
# Why this is honest, not cheating:
#   - glibc/gccLib/zlib/zstd are stock nixpkgs outputs already in
#     cache.nixos.org; formatelf is this repo's own package (numtide cache).
#     Nothing is rebuilt-the-world that wasn't already.
#   - storePath references cost ~0 at eval time (no derivation graph walked),
#     so eval stays nixpkgs-free even though the artifacts come from nixpkgs.
#   - Regenerate these lines whenever the pins bump (a lockfile, `nix eval` once).
{
  glibc = builtins.storePath /nix/store/0d8g8n0a11v6f5m2h416ajyxmnkwc3md-glibc-2.42-67;
  formatelf = builtins.storePath /nix/store/r6a970q9v1bzdfrd8dcqjmnfs94lh45g-formatelf-0-unstable-2026-08-11;
  gccLib = builtins.storePath /nix/store/r48746qznwqxxl9qzd8f08ny8mg1dg2y-gcc-15.3.0-lib;
  zlib = builtins.storePath /nix/store/zks9mfsn4rqr6z9g6pcj2xqzcsplj0nb-zlib-1.3.2;
  zstd = builtins.storePath /nix/store/pxahscw9vl9vac1nbjpy6bhz3vbk3cpl-zstd-1.5.7;
}
