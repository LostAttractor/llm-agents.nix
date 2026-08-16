# Pure-Nix .drv rehydration — prototype findings

Goal: make the standalone (nixpkgs-free) pins **rebuildable from source** instead
of appendContext store-path references that dead-end when cache.nixos.org GCs
them. Approach: serialize a pin's `.drv` closure (`nix derivation show -r`) and
replay it in **pure Nix** (no `nix derivation add`, no store mutation) via
`builtins.derivation` + `builtins.appendContext`, landing the identical drvPath.

## What works (see `rehydrate.nix`)

Reconstructs a node by re-attaching input dependencies as string context and
handing the result to `builtins.derivation`. Verified to reproduce the **exact
drvPath** for, in order of the bugs found and fixed:

1. no-input derivations — but only if you DON'T pass `outputs=["out"]` (that adds
   an `outputs` env var the default single-output derivation lacks).
2. multi-node closures with inter-dependencies (context via `replaceStrings`).
3. self-references (`$out` in args/env) — reverse the resolved output path back
   to `builtins.placeholder`.
4. FOD-with-inputs (`hex0`, the stage0 seed) — but the **`builder`** field must
   be recontexted too, or the seed dependency edge is dropped.
5. multi-output order — the real order is `env.outputs` ("out bin"), not
   `attrNames` (sorted).
6. `preferLocalBuild`/`allowSubstitutes`/`__structuredAttrs` serialize as "1"/""
   strings but `builtins.derivation` wants bools.

Performance: **must memoize** — the closure is a DAG with heavy sharing
(bootstrap-tools/gcc/stdenv), so naive recursion is exponential (9 min → 0.4 s
with a lazy fixpoint memo).

Result on `glibc-2.42-67` (400-node closure): **395 / 400 nodes reproduce the
exact drvPath.**

## The wall: 5 "minimal-env" bootstrap derivations

`libunistring`, `which`, `xgcc`, `gmp`, `mpfr` (and similar gcc-bootstrap nodes)
have a `.drv` whose `env` contains **only the output paths** — no
`name`/`system`/`builder`/`outputs`. Their build config lives entirely in the
stdenv default-builder + structural fields.

`builtins.derivation` AND `builtins.derivationStrict` both **always inject**
`name`/`system`/`builder` (and `outputs` for multi-output) into the env. So a
pure-Nix eval cannot produce an outputs-only env — these 5 nodes always come out
with a different drvPath, which cascades to every dependent.

There is no public pure-Nix builtin that writes an arbitrary `.drv` verbatim.

## Recommendation

Pure-Nix rehydration is ~99% there but **not complete** for a stdenv-bootstrap
closure. Options:

- **Hybrid (recommended):** pure-Nix `builtins.derivation` for the reproducible
  majority; `nix derivation add` (a one-time bootstrap step, store mutation) for
  the handful of minimal-env nodes. Small, bounded escape hatch.
- **Full `nix derivation add`:** replays the whole closure verbatim, handles
  every node, but is entirely a store-mutation step (not eval).
- **appendContext the 5 outputs:** keeps eval pure but those 5 stay
  cache-dependent (no source rebuild) — a smaller version of today's problem.

`rehydrate.nix` is the pure-Nix engine for the first path.
