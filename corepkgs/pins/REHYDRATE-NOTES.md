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
1. multi-node closures with inter-dependencies (context via `replaceStrings`).
1. self-references (`$out` in args/env) — reverse the resolved output path back
   to `builtins.placeholder`.
1. FOD-with-inputs (`hex0`, the stage0 seed) — but the **`builder`** field must
   be recontexted too, or the seed dependency edge is dropped.
1. multi-output order — the real order is `env.outputs` ("out bin"), not
   `attrNames` (sorted).
1. `preferLocalBuild`/`allowSubstitutes`/`__structuredAttrs` serialize as "1"/""
   strings but `builtins.derivation` wants bools.

Performance: **must memoize** — the closure is a DAG with heavy sharing
(bootstrap-tools/gcc/stdenv), so naive recursion is exponential (9 min → 0.4 s
with a lazy fixpoint memo).

Result on `glibc-2.42-67` (400-node closure): **395 / 400 nodes reproduce the
exact drvPath.**

## The "minimal-env" nodes: it's `__structuredAttrs` (handleable)

5/400 nodes (`libunistring`, `libxcrypt`, `python3-minimal`, `which`, `xgcc`)
have a `.drv` whose `env` is **only the output paths**. First read as a wall,
but the v4 JSON has a top-level `structuredAttrs` field carrying the full config
(src/stdenv/buildInputs/…): these packages set `__structuredAttrs = true` in
their nixpkgs `package.nix` (stdenv defaults it off:
`structuredAttrsByDefault = config.structuredAttrsByDefault or false`). For
structuredAttrs, Nix passes attrs via a generated `.attrs.json`, so the env is
minimal *by design*. Early adopters of nixpkgs' migration; the count grows over
time.

`builtins.derivation { __structuredAttrs = true; … }` reproduces that shape
(verified — minimal env, `structuredAttrs` set). So the fix is: for a
structuredAttrs node, recontext its `structuredAttrs` field recursively (strings
in nested lists/attrs get input/self context) and pass it plus
`__structuredAttrs = true`. Then pure-Nix rehydration is **complete (400/400)** —
TODO in `rehydrate.nix` (currently handles the 395 classic-env nodes).

## Source files: what has to be inlined to be GC-proof

The closure's leaves are two kinds:

- **FOD tarballs (114 nodes):** upstream source (glibc/gcc/…), fetched **by
  hash**. Already durable — refetchable from anywhere.
- **inputSrcs (104 files, ~824 KB):** the `"${./patch}"` / `builtins.path`
  interpolations — glibc patches, CVE fixes, setup hooks (`add-flags.sh`,
  `audit-tmpdir.sh`, `default-builder.sh`), `.m4` macros. These are nixpkgs
  source-tree files, NOT fetchable by URL.

`rehydrate.nix` currently references the 104 via `builtins.storePath` — which
still requires them present/substitutable, i.e. the same cache-GC exposure moved
onto small files. To be truly GC-proof, **inline the 104 files into the repo**
(commit ~824 KB, re-add via `builtins.path` → identical store path by content).
Then the standalone flake is self-contained: rehydrated `.drv` graph + committed
patch/hook files + hash-fetched upstream tarballs. Nothing depends on cache
retention.

## Status

Pure-Nix rehydration is viable and (with structuredAttrs handling) complete for a
stdenv-bootstrap closure — no `nix derivation add`, no store mutation. Remaining
to make it a real durable `pins` backend: (1) recursive recontext for
structuredAttrs nodes, (2) inline the 104 inputSrc files.
