# The nixpkgs boundary.
#
# The seed userland (seed.nix) is 100% nixpkgs-free. But prebuilt toolchains
# (bun, node, rust) are dynamically linked to glibc, and the Nix sandbox has no
# loader. Fixing that needs glibc + patchelf. Bootstrapping glibc from source
# is rebuilding stdenv, which is the whole point we are avoiding - so instead we
# PIN the standard nixpkgs glibc/patchelf by store path.
#
# Why this is honest, not cheating:
#   - These are stock nixpkgs outputs, already in cache.nixos.org, so no
#     rebuild-the-world for anyone.
#   - storePath references cost ~0 at eval time (no derivation graph walked),
#     so eval stays nixpkgs-free even though the artifacts come from nixpkgs.
#   - Regenerate these three lines whenever the pinned nixpkgs bumps (a
#     lockfile, produced by `nix eval` once).
{
  glibc = builtins.storePath /nix/store/0d8g8n0a11v6f5m2h416ajyxmnkwc3md-glibc-2.42-67;
  patchelf = builtins.storePath /nix/store/iyinjjn7gv8c77w9qgicfmz4mc4dwq5j-patchelf-0.15.2;
  gccLib = builtins.storePath /nix/store/r48746qznwqxxl9qzd8f08ny8mg1dg2y-gcc-15.3.0-lib;
}
