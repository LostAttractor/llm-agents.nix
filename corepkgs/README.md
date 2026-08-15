# corepkgs

A nixpkgs-free packaging system: build the repo's agent tools with **no nixpkgs
and no `stdenv`** at build time. For the prebuilt-binary CLIs that make up most
of this repo, a "build" is really just *fetch a release artifact → make it run
on NixOS (patch the ELF interpreter/rpath, or loader-wrap a `bun --compile`
binary) → wrap it* — a tiny sliver of what `stdenv` does. corepkgs does that
sliver on a static busybox + nushell seed.

## Using it

corepkgs is both an importable library and a standalone flake:

```nix
# from the root flake (how packages/<name>/package.nix are built):
core = import ./corepkgs { inherit system; pkgs = <nixpkgs for system>; };
core.lib.mkBinary { pname = "grok"; hashesFile = ./hashes.json; ... };
```

```console
# standalone (pins from storePath, zero nixpkgs — impure, fast eval):
$ nix eval -f corepkgs --impure packages.hello.drvPath
# or as a real flake (pins from nixpkgs):
$ nix build ./corepkgs#packages.x86_64-linux.formatelf
```

A `packages/<name>/package.nix` that declares `mkBinary` *is* a corepkgs build;
`callPackage` resolves it from the flake scope. It carries `meta` +
`passthru.category` + `passthru.updater`, so meta-completeness, the README
generator, and the declarative updater treat it like any other package.

## Layout

```
default.nix       the importable API: { lib, packages, pins }
flake.nix         standalone flake wrapping default.nix
systems.nix       per-system table (loader, seed/toolchain URLs+hashes)
seed.nix          the bootstrap seed (static busybox + static nushell), zero nixpkgs
interpolate.nix   {name}-template interpolation (owned; the root imports it from here)
fetchurl.nix      naked builtin:fetchurl (flat + executable)
naked-fetchurl.nix  the eval-fast fetchurl the root routes bun2nix through
pins-pkgs.nix     THE nixpkgs boundary: glibc/gccLib/formatelf/... from pkgs (pure, for the flake)
pins-store.nix    the same pins as storePath (impure, ~instant eval, for standalone use)
mk/
  naked.nix       the ~10-line mkDerivation replacement. Builder = a truly-static
                  nushell; __structuredAttrs exposes derivation attrs as JSON the
                  script `open`s natively (real records, no string-munged env).
  naked-sh.nix    the tiny /bin/sh bootstrap that extracts nushell from its tarball
                  (chicken-and-egg) and builds the toolchains
  binary.nix      mkBinary — the nixpkgs-free platformSource + autoPatchelf + makeWrapper
  check-fhs.nix   assert an output is store-only (no ELF left on a host loader)
toolchains/       bun, node, rust, zig, python from upstream prebuilt binaries
                  (the basis for source-built ports; not yet used by shipped packages)
formatelf.nix     dogfood: build formatelf from source, nixpkgs-free (rust + zig cc)
cargo-vendor.nix  vendor a Cargo.lock as naked builtin:fetchurl FODs
```

## mkBinary knobs

`mk/binary.nix` covers every shape the repo's prebuilt-binary packages take:

- **Source**: `hashesFile` + `urlTemplate` (reuse the shared `hashes.json`, no
  drift) with a `platforms` map (string `{platform}` token, or an attrset of
  arbitrary URL vars); or a literal `src` + `version`.
- **`unpack`**: `none` / `tar` / `zip` / `auto` (infer from the URL extension, so
  one package can serve platforms whose assets differ — darwin `.zip` vs linux
  `.tar.gz`). `binary` (nested path), `installDir` (copy a whole tree),
  `entrypoint` (a nested launcher distinct from the wrapper name).
- **`kind`**: `patchelf` (rewrite ELF interpreter/rpath via [formatelf](https://github.com/Mic92/formatelf))
  or `loader` (leave a bun-compiled / SEA binary byte-intact and invoke the
  pinned loader through the wrapper — patchelf corrupts their appended payload).
  Darwin needs neither: Mach-O CLIs link the always-present system `libSystem`.
- **Runtime**: `libs`, `runtimeBins` (bundled binaries on PATH), `runtimePkgs`
  (pinned tools on PATH), `setEnv`, `extraArgs` (wrapper flags), `aliases`
  (argv0-dispatched extra wrappers), `ignoreMissing` (SONAME allowlist for a
  bundled JRE's optional AWT/X11 libs).
- **Metadata**: `meta`, `category`, `updater` — carried onto the naked
  derivation so the flake's package machinery treats it normally.

## Eval cost

Fully nixpkgs-free eval is cheap: resolving a package drvPath standalone
(storePath pins, zero nixpkgs) is **~59 ms** vs **~1.2 s** through the repo flake
(which imports nixpkgs) — ~20×. Note the honest caveat: *inside* the current
repo flake there is no eval win yet, because the flake still imports nixpkgs for
the pins and the un-ported packages, and pure eval forbids `builtins.storePath`
(so the flake uses the nixpkgs-sourced pins). The eval win is realized as the
tree becomes fully corepkgs.

## Bootstrap

The seed is currently trusted static upstream builds (busybox, nushell). The
next steps toward a real trust chain are our own source-built bootstrap tarballs
on a GitHub release, and eventually a GNU Mes bootstrap. The seed layer
(`seed.nix` + `systems.nix`) is kept small and swappable for exactly this.
