# naked: a nixpkgs-free build layer (spike)

Can we build our packages without importing nixpkgs and without `stdenv`? The
flamegraph said the eval cost is ~47% `mkDerivation` + toolchain/dep evaluation.
This spike rebuilds the bottom of the stack with naked `builtin:fetchurl`
fetchers, a ~10-line `mkDerivation` replacement, and toolchains bootstrapped
from upstream prebuilt binaries.

Build anything here with `nix build -f naked <attr>`.

## Architecture

```
seed.nix      two truly-static prebuilt binaries fetched by URL, zero nixpkgs:
              - bash-static (the builder; ignores argv[0], so it runs from a
                hash-prefixed store path — Nix always sets argv[0]=builder)
              - busybox-musl (sh + coreutils + tar/gzip/unzip in one binary)
mk-naked.nix  the mkDerivation replacement. Builder = seed bash; it boots
              busybox applets into PATH via `exec -a busybox` (busybox
              dispatches on argv[0], which Nix hash-prefixes) then runs the
              build script. ~10 lines vs stdenv's ~2000.
fetchurl.nix  naked builtin:fetchurl (flat + executable variants)
pinned.nix    THE nixpkgs boundary (see below)
toolchains/   bun, node, rust from upstream prebuilt binaries
```

## What works (all built + run in a nixpkgs-free sandbox, x86_64-linux)

| target | result |
|---|---|
| `hello` | seed userland smoke test (mkdir/cp/ln/chmod) — builds + runs |
| `bun` | `bun --version` → 1.3.14. Wrapped with the pinned loader, **not** patchelf'd (bun's appended runtime payload segfaults on any ELF rewrite) |
| `node` | `node --version` → v22.14.0, runs JS. patchelf'd (safe: no appended payload) |
| `rust` | `rustc 1.83.0` + `cargo 1.83.0` run; `rustc` compiles source → rlib (full frontend + LLVM codegen + std) |

**Eval payoff:** the three naked toolchains resolve their drvPaths in **0.05s**
vs **1.0s** for the nixpkgs equivalents — ~20×, and the naked layer imports
*zero* nixpkgs.

## The honest boundary: `pinned.nix`

The seed userland is 100% nixpkgs-free. But prebuilt bun/node/rust are
dynamically linked to glibc, and the Nix sandbox has no loader. Fixing that
needs `glibc` + `patchelf` (+ `zlib`/`zstd` for rustc). Bootstrapping glibc from
source *is* rebuilding stdenv — the thing we're avoiding. So we **pin** the
stock nixpkgs glibc/patchelf/zlib/zstd by store path:

- they're stock nixpkgs outputs already in `cache.nixos.org` → no
  rebuild-the-world for anyone;
- `storePath` references cost ~0 at eval → eval stays nixpkgs-free even though
  the artifacts come from nixpkgs;
- the paths are a hand-rolled lockfile — regenerate on a nixpkgs bump.

This is the same reasoning as pinning chromium: a bounded, cache-substitutable
pin, not a fork.

## What is NOT done (limitations)

- **Rust can't link executables.** rustc compiles to rlib/obj here, but linking
  a binary needs a C toolchain (crt objects + `ld` + libc). That's another pin
  (cc/binutils/glibc-dev) or shipping `rust-lld` + crt — not attempted.
- **x86_64-linux only.** URLs, hashes, and pinned paths are hardcoded per-arch.
- **Toolchain layer only.** No per-package builders yet (the `buildNpmPackage` /
  bun-package / `buildRustPackage` equivalents). This proves the *base*; the
  packages still need porting onto it to actually shed `mkDerivation`.
- **Darwin unaddressed.**
- **The glibc/patchelf pin is an irreducible tie** short of bootstrapping libc.

## Takeaway

The architecture works: naked fetchers + a tiny builder + prebuilt toolchains
build real software with no nixpkgs eval, ~20× faster at the toolchain layer.
But "remove nixpkgs" is ~90%: the last mile (libc, the C linker) is where you
either pin from the standard cache (pragmatic, done here) or rebuild stdenv
(huge). And the flamegraph's `mkDerivation` tax only disappears for packages
actually *ported onto* this base — the toolchains alone don't move the full-set
number.
