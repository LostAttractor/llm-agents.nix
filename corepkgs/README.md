# corepkgs

A nixpkgs-free packaging system: build the repo's agent tools with **no nixpkgs
and no `stdenv`** at build time. For the prebuilt-binary CLIs that make up most
of this repo, a "build" is really just *fetch a release artifact → make it run
on NixOS (patch the ELF interpreter/rpath, or loader-wrap a `bun --compile`
binary) → wrap it* — a tiny sliver of what `stdenv` does. corepkgs does that
sliver, and the from-source builds, on a static busybox + nushell seed.

## Two tiers: derivations and packages

- **derivations** — the small building blocks: `mkDrv` (nushell +
  `__structuredAttrs`) and `mkDrvSh` (POSIX sh + busybox). Also used for vendor
  FODs, the fhs check, and the seed. Not necessarily installable.
- **packages** — installable things (a `bin/` + `meta.mainProgram` you can
  `nix profile install`): `mkPackage` (prebuilt binary → package) plus the
  from-source constructors `mkCargo` · `mkGo` · `mkNpm` · `mkBun` · `mkPnpm` ·
  `mkPython`.

## Using it

corepkgs is both an importable library and a standalone flake:

```nix
# from the root flake (how packages/<name>/package.nix are built):
core = import ./corepkgs { inherit system; pkgs = <nixpkgs for system>; };
core.lib.mkPackage { pname = "grok"; hashesFile = ./hashes.json; ... };
```

```console
# standalone — zero nixpkgs input, pure + offline eval (appendContext pins):
$ nix eval ./corepkgs#packages.x86_64-linux.hello.drvPath
$ nix build ./corepkgs#packages.x86_64-linux.rust-bin
```

A `packages/<name>/package.nix` that declares a constructor (`mkPackage`,
`mkCargo`, …) *is* a corepkgs build; `callPackage` resolves it from the flake
scope. It carries `meta` + `passthru.category` + `passthru.updater`, and its
version + hashes live in a sibling `hashes.json` (the file nix-update bumps), so
meta-completeness, the README generator, and the updater treat it like any other
package.

## Layout

The top-level holds only the entry points + docs; everything else is a directory.

```
default.nix     the importable API: { lib, packages, pins, toolchains, machinery, system }
flake.nix       standalone flake (ZERO inputs) wrapping default.nix
mk/             constructors + derivation primitives
  drv.nix       the ~10-line mkDerivation replacement. Builder = a truly-static
                nushell; __structuredAttrs exposes derivation attrs as JSON.
  drv-sh.nix    the tiny /bin/sh + busybox builder (bootstraps nushell, and runs
                the toolchain + source-package builds)
  package.nix   mkPackage — prebuilt-binary → package (platformSource + patchelf/
                loader-wrap + makeWrapper)
  cargo.nix go.nix npm.nix bun.nix pnpm.nix python.nix   from-source constructors
  check-fhs.nix assert an output is store-only (no ELF left on a host loader)
vendor/         dependency vendorers (cargo/go/npm/bun/pnpm/python)
toolchains/     default.nix — the provider; maps logical keys (rust, go, …) to the
                -bin toolchain packages, threaded through the constructor scope
fetch/          fetch primitives (fetchurl · builtin-fetchurl · interpolate ·
                fetchurl-template · platform-source) — all builtin:fetchurl
lib/            meta helpers (mk-updater, mk-update-script, maintainers)
pins/           the pin providers: pkgs.nix (from nixpkgs) · store.nix (storePath)
                · closure.nix (appendContext — pure, nixpkgs-free, offline eval)
seed/           default.nix = the busybox+nushell seed · systems.nix = per-arch
                platform tokens + rust triples
packages/       corepkgs' OWN by-name packages: the machinery helpers (formatelf,
                wrapBuddy, buildNpmPackage, versionCheckHomeHook) + the -bin
                toolchains (bun-bin, node-bin, rust-bin, …), each with a hashes.json
```

## Two swappable seed layers

corepkgs' only external dependency is threaded in as two attrsets, each a default
arg you can override without touching a constructor — the **bootstrap seam**:

- **`pins`** — prebuilt C libs/tools (glibc, gccLib, openssl, formatelf, …).
  Default `pins/closure.nix` references the exact store paths via
  `builtins.appendContext` (the nixpkgs-multiverse "fast mode" trick): pure,
  nixpkgs-free, and cache-free at eval; substituted from cache.nixos.org /
  cache.numtide.com at build time. The root flake passes `pkgs`, so `pins/pkgs.nix`
  can rebuild them from source on a cache miss.
- **`toolchains`** — rust, go, node, zig, bun, pnpm, python. Fetched prebuilt
  from upstream (`packages/<name>-bin/`); the toolchain a constructor uses *is*
  `core.packages.<name>-bin` (single source of truth).

## mkPackage knobs

`mk/package.nix` covers every shape the repo's prebuilt-binary packages take:

- **Source**: `hashesFile` + `urlTemplate` (reuse the shared `hashes.json`) with
  a `platforms` map; or a literal `src` + `version`.
- **`unpack`**: `none` / `tar` / `zip` / `auto`; `binary` (nested path),
  `installDir` (copy a whole tree), `entrypoint`.
- **`kind`**: `patchelf` (rewrite ELF interpreter/rpath via
  [formatelf](https://github.com/Mic92/formatelf)) or `loader` (leave a
  bun-compiled / SEA binary byte-intact and invoke the pinned loader through the
  wrapper — patchelf corrupts their appended payload). Darwin needs neither.
- **Runtime**: `libs`, `runtimeBins`, `runtimePkgs`, `setEnv`, `extraArgs`,
  `aliases` (argv0-dispatched wrappers), `ignoreMissing`.

## From-source constructors

Each fetches the upstream toolchain and vendors deps, nixpkgs-free:

- **mkCargo** (rust) — `zig cc` as the C linker; crates vendored per-crate by
  sha256 from `Cargo.lock` (no vendorHash); each exe post-link-patched to the
  pinned glibc. Handles bundled-C (`cc` crate), workspaces (`sourceRoot`/`-p`),
  `openssl`, `gitDeps` (repo-root git deps), `extraEnv`, `patches`.
- **mkGo** — `CGO_ENABLED=0` → a fully static binary (trivial FHS). One
  `vendorHash` FOD, **byte-identical to nixpkgs' `buildGoModule`**, so a ported
  package reuses its existing hash. `cgo = true` compiles cgo C via zig cc.
- **mkNpm / mkBun / mkPnpm** — vendor `node_modules` as one FOD (our
  `npmDepsHash` / `bunDepsHash` / `pnpmDepsHash`), run the build, wrap the entry
  on the node/bun toolchain. Bundled `.node` addons are patchelf'd to glibc.
- **mkPython** — `pip install --target` FOD (our `pythonDepsHash`); wraps
  `[project.scripts]` on the relocatable-CPython toolchain. Manylinux wheels OK.

Out of scope (real blockers): system C libs not in the pin set, workspace-member
git deps, heavy native bundles (torch/sharp), electron/tauri.

## Bootstrap

The seed is currently trusted static upstream builds (busybox, nushell) and the
pins are stock cache.nixos.org paths. The next steps toward a real trust chain
are our own source-built bootstrap tarballs on a GitHub release, and eventually a
GNU Mes bootstrap. Both `pins` and `toolchains` are swappable providers for
exactly this — a from-source bootstrap is a provider swap, no constructor
changes.
