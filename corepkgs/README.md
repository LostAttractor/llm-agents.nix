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
pins-pkgs.nix     THE nixpkgs boundary: glibc/gccLib/formatelf/openssl/... from pkgs (pure, for the flake)
pins-store.nix    the same pins as storePath (impure, ~instant eval, for standalone use)
fetch/            all fetcher machinery, together
  fetchurl.nix · naked-fetchurl.nix · interpolate.nix · fetchurl-template.nix · platform-source.nix
mk/               the constructors
  naked.nix       the ~10-line mkDerivation replacement. Builder = a truly-static
                  nushell; __structuredAttrs exposes derivation attrs as JSON the
                  script `open`s natively (real records, no string-munged env).
  naked-sh.nix    the tiny /bin/sh bootstrap that extracts nushell from its tarball
                  (chicken-and-egg) and builds the toolchains + source packages
  binary.nix      mkBinary — nixpkgs-free platformSource + autoPatchelf + makeWrapper
  cargo.nix       mkCargo — build a Rust package from source (rust + zig cc + vendored crates)
  go.nix          mkGo    — build a Go package from source, fully static (CGO_ENABLED=0)
  check-fhs.nix   assert an output is store-only (no ELF left on a host loader)
lib/              build helpers (mk-updater, mk-update-script, rusty-v8, maintainers, ...)
toolchains/       bun, node, rust, zig, go, python from upstream prebuilt binaries
vendor/           dependency vendorers
  cargo.nix       vendor a Cargo.lock as naked builtin:fetchurl FODs (per-crate, by sha256)
  go.nix          vendor go modules as one vendorHash FOD (go.sum h1: hashes aren't fetchurl-able)
packages/         corepkgs' OWN packages, by-name (formatelf, wrapBuddy, buildNpmPackage, ...)
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

## Source builds — mkCargo (Rust) / mkGo (Go)

Not every package ships a prebuilt binary. `mk/cargo.nix` and `mk/go.nix` build
from source, nixpkgs-free, on the fetched upstream toolchains.

**mkCargo** — rust source builds: naked rust toolchain, `zig cc` as the C
linker, crates vendored by `vendor/cargo.nix`, each produced executable
post-link-patched to the pinned glibc by formatelf. Handles:

- pure crates.io, and **bundled C** (crates that compile their own C via the
  `cc` crate — tree-sitter grammars, `libsqlite3-sys`/`rusqlite` bundled,
  `libgit2-sys`, `ring`, quickjs, brotli, zstd/bzip2/lzma-sys …) using zig cc +
  zig's llvm `ar`/`ranlib`;
- **subdir workspaces** (`sourceRoot`, `cargoBuildFlags = ["-p" "crate"]`);
- an **authoritative vendored `Cargo.lock`** (copied over the source's, `--locked`
  dropped) — fixes tarballs whose in-tree lock is stale;
- **openssl** (`openssl = true`): the pinned openssl (`OPENSSL_NO_VENDOR` +
  lib/include dirs + pkg-config), so `openssl-sys`/`native-tls` link our openssl
  instead of a system lib or an `openssl-src` build that needs perl.
- Out of scope: `git`-dependency crates (need a git vendorer), and rust crates
  that embed a separately-built JS frontend at compile time.

**mkGo** — go source builds: naked go toolchain, `CGO_ENABLED=0`, so the output
is a **fully static binary** — no glibc, no patchelf, no wrapper; it just runs,
and the FHS check is trivial. Modules are vendored by `vendor/go.nix` as one
`vendorHash` FOD (go.sum `h1:` tree-hashes aren't fetchurl-compatible, so — like
nixpkgs' `buildGoModule` — `go mod vendor` runs with network and the caller
commits the hash). **The vendorHash equals nixpkgs' `buildGoModule` vendorHash
byte-for-byte**, so an existing package's `hashes.json` vendorHash is reused
as-is when porting.

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
