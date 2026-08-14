# naked: a nixpkgs-free build layer (spike)

Can we build our packages without importing nixpkgs and without `stdenv`? The
flamegraph said the eval cost is ~47% `mkDerivation` + toolchain/dep evaluation.
This spike rebuilds the bottom of the stack with naked `builtin:fetchurl`
fetchers, a ~10-line `mkDerivation` replacement, and toolchains bootstrapped
from upstream prebuilt binaries.

Build anything here with `nix build -f naked <attr>`.

## Architecture

```
seed.nix      ONE truly-static prebuilt binary fetched by URL, zero nixpkgs:
              busybox-musl (sh + coreutils + tar/gzip/xz/unzip). The build
              *builder* is the sandbox's own /bin/sh (Nix guarantees it), so we
              don't even fetch a shell.
mk-naked.nix  the mkDerivation replacement. Builder = /bin/sh; it boots busybox
              applets into PATH via `exec -a busybox` (busybox dispatches on
              argv[0], which Nix hash-prefixes) then runs the build script.
              ~10 lines vs stdenv's ~2000.
fetchurl.nix  naked builtin:fetchurl (flat + executable variants)
pinned.nix    THE nixpkgs boundary (see below)
toolchains/   bun, node, rust, zig from upstream prebuilt binaries
```

## What works (all built + run in a nixpkgs-free sandbox, x86_64-linux)

| target | result |
|---|---|
| `hello` | seed userland smoke test (mkdir/cp/ln/chmod) — builds + runs |
| `bun` | `bun --version` → 1.3.14. Wrapped with the pinned loader, **not** patchelf'd (bun's appended runtime payload segfaults on any ELF rewrite) |
| `node` | `node --version` → v22.14.0, runs JS. patchelf'd (safe: no appended payload) |
| `rust` | `rustc 1.83.0` + `cargo 1.83.0` run; compiles source → rlib, and (with zig) links full executables |
| `zig` | `zig cc` — a self-contained C/C++ compiler + linker + libc, **no glibc pin**. Emits fully static musl binaries. |
| `rust-zig-link-demo` | prebuilt rustc + `zig cc` → a **fully static** rust executable (no PT_INTERP, no glibc, no nixpkgs) that runs |

**Eval payoff:** the naked toolchains resolve their drvPaths in **0.05s** vs
**1.0s** for the nixpkgs equivalents — ~20×, and the naked layer imports *zero*
nixpkgs.

## Ported binary-wrapper packages

`mk-binary.nix` is the nixpkgs-free equivalent of `platformSource` +
`autoPatchelfHook` + `makeWrapper`. Its knobs, grown to cover every shape the
repo's prebuilt-binary packages take:

- `unpack` none/zip/tar, `binary` (nested path), `installDir` (copy a whole
  tree), `entrypoint` (nested launcher distinct from the wrapper name).
- `kind` = `patchelf` (rewrite ELF interpreter/rpath) or `loader` (leave a
  bun-compiled / Node-SEA binary byte-intact and wrap it - patchelf segfaults
  their appended payload).
- `libs` (extra lib pins), `runtimeBins` (bundled binaries on PATH),
  `runtimePkgs` (pinned tools on PATH), `setEnv` (wrapper env exports),
  `ignoreMissing` (SONAME allowlist for a bundled JRE's optional AWT/X11 libs).
- dir-install indexes the tree's own lib dirs so intra-tree deps (a JRE's
  `libjli.so`) resolve.

**23 packages ported**, all building + running + passing the FHS check
(`nix build -f naked <pkg>` / `checks.<pkg>`, and the pure flake path):
amp, antigravity-cli, claude-code, cline, coderabbit-cli, copilot-cli, cubic,
cursor-agent, droid, eca, forgecode, freebuff, grok, jules, junie, kilocode-cli,
memvid-cli, mimo-code, open-code-review, opencode, opencode2, qoder-cli, swamp.

**`check-fhs.nix`** guards each: every ELF in the output must resolve within
`/nix/store` (mechanism-aware: patchelf via rpath, loader via the wrapper
library-path, `ignoreMissing` SONAMEs skipped). It repeatedly caught real
runtime breakage (a cursor-agent native module needing `libz`, a JRE's
`libjli.so`) that `--version` never exercised.

**python toolchain** (`nix build -f naked python`): relocatable prebuilt CPython
(astral python-build-standalone), patchelf'd to the pinned glibc; the wrapper
sets `LD_LIBRARY_PATH` to the pinned **manylinux** external libs
(libffi/expat/ncurses/openssl/bzip2/xz + glibc/gccLib/zlib) so wheels' compiled
extensions resolve. Runs 3.12.14 with stdlib C-extensions.

Two prebuilt packages are NOT portable: **claude-desktop** and **handy** -
Electron/Tauri GUI apps that link GTK/webkit/vulkan/alsa (not in the pin set)
and ship as `.deb` (which `unpack` doesn't handle). Every other prebuilt-binary
package in the repo is ported; the rest are source-built (npm/rust/go/bun),
which the naked *toolchains* could compile but which this spike doesn't port.

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

## What the glibc pin is now (and isn't) for

zig closed the "last mile": **building/linking** our own code needs no nixpkgs
and no glibc — `zig cc` is a complete static C toolchain. The pinned
glibc/patchelf is now needed only to **run the upstream prebuilt toolchain
binaries** (bun/node/rustc ship glibc-dynamic). Output artifacts built through
zig depend on nothing. Fully dropping the pin would mean either upstream musl
toolchain builds or rebuilding glibc (= stdenv).

## What is NOT done (limitations)

- **x86_64-linux only.** URLs, hashes, and pinned paths are hardcoded per-arch.
- **Toolchain layer only.** No per-package builders yet (the `buildNpmPackage` /
  bun-package / `buildRustPackage` equivalents). This proves the *base*; the
  packages still need porting onto it to actually shed `mkDerivation`.
- **Darwin unaddressed.**
- **glibc + formatelf still pinned** to run the glibc-dynamic upstream toolchains.

## Takeaway

The architecture works: naked fetchers + a tiny builder + prebuilt toolchains +
`zig cc` build and link real software (down to fully static rust binaries) with
no nixpkgs eval, ~20× faster at the toolchain layer. "Remove nixpkgs" for the
fetch → toolchain → compile → link → wrap path is essentially done; the only
residual nixpkgs tie is the glibc needed to *run* the upstream prebuilt
toolchains. The flamegraph's `mkDerivation` tax only disappears for packages
actually *ported onto* this base — the next step is porting the per-package
builders, starting with the binary-wrapper packages (fetch + patchelf + wrap).
