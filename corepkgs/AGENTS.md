# corepkgs — Agent Guidelines

corepkgs is this repo's **nixpkgs-free packaging system**. It builds tools with
no nixpkgs and no stdenv at build time, using a truly-static nushell as the
builder. The standalone flake (`corepkgs/flake.nix`) has **zero inputs**.

## Consumer contract (important)

A consumer (the root `flake.nix`, checks, scripts) must reach corepkgs **only
through the entry point** — `core = import ./corepkgs { ... }` — and then use
`core.*`. **Never path-import a file under `corepkgs/`** (no
`import ./corepkgs/lib/foo.nix`, no `readDir ./corepkgs/packages`). corepkgs owns
its layout; the consumer owns supplying nixpkgs deps to the functions it exposes.

The surface:

- `core.lib` — the builder API + primitives: `mkBinary`, `mkCargo`, `mkGo`,
  `mkNpm`, `mkPython`, `mkNaked`, `mkNakedSh`, `checkFhs`, `coreFetchurl`,
  `interpolate`, `fetchurlTemplate`, `platformSource`, and the meta helpers
  `mkUpdater` / `mkUpdateScript` / `flakeLib` (un-called functions — the consumer
  passes its own `lib`/tools/`inputs`).
- `core.pins` — prebuilt C libraries + tools.
- `core.toolchains` — the compilers/runtimes we build with.
- `core.packages` — corepkgs' own buildable outputs (toolchains + `hello`).
- `core.machinery` — the by-name helper package **functions** (formatelf,
  wrapBuddy, buildNpmPackage, versionCheckHomeHook); the consumer `callPackage`s
  them into its scope.
- `core.system`.

## Two seed layers, both swappable providers

corepkgs' only external dependency is two threaded "seed" attrsets, each a
default arg you can override without touching a constructor:

- **`pins`** — prebuilt C libs/tools (glibc, gccLib, openssl, zlib, formatelf,
  ...). Default: `pins-closure.nix`, which `builtins.fetchClosure`es the exact
  store paths from cache.nixos.org (formatelf from cache.numtide.com) — pure and
  nixpkgs-free. When the root passes `pkgs`, `pins-pkgs.nix` reuses it (so CI can
  rebuild pins from source on a cache miss). Regenerate the paths in
  `pins-closure.nix` **and** `pins-store.nix` on a nixpkgs/formatelf bump.
- **`toolchains`** — rust, go, node, zig, bun, python (+ seed). Default:
  `toolchains/default.nix` (fetched prebuilt). The toolchain a constructor uses
  IS `core.packages.<name>` (single source of truth).

Swapping either provider is the **bootstrap seam** — e.g. a from-source /
GNU Mes bootstrap is a provider swap, no constructor changes.

## Constructors and the FOD hash pattern

- `mkBinary` — prebuilt binaries (patchelf/loader/wrap).
- `mkCargo` — rust from source. Per-crate crates.io FODs from `Cargo.lock`
  (**no** vendorHash; the lock's sha256s drive + verify fetches). Knobs:
  `openssl`, `buildInputs`, `cargoBuildFlags`, `extraEnv`, `gitDeps` (github-
  archive git-source vendorer for repo-root crates).
- `mkGo` — go from source. One `vendorHash` FOD (== nixpkgs' byte-for-byte —
  reuse existing hashes). `cgo = true` for cgo C via zig cc.
- `mkNpm` — npm from source. `node_modules` FOD (OUR `npmDepsHash`). Knobs:
  `packageLock` (inject a committed lock), `binWrappers`, `nativeAddons`
  (patchelf bundled `.node`), `omitOptional`.
- `mkPython` — python app from source. `pip install --target` FOD
  (OUR `pythonDepsHash`); wraps `[project.scripts]`. Manylinux-wheel deps OK.

**Computing a FOD hash:** write the package with a placeholder
(`sha256-AAAA...=`), run `nix build --no-link .#<pkg> 2>&1 | grep -oP 'got:\s+\Ksha256-\S+'`, and paste it in. Never compute the hash from a separate
`--expr` with shell-escaped args (the escaping diverges from the real
package.nix and yields a stale hash).

## FHS check

`checkFhs` asserts a package output is **store-only** — no host loader, every
NEEDED lib resolves inside /nix/store. It expands `$ORIGIN`, so manylinux wheels
that bundle private libs in a `*.libs/` sibling dir pass.

## Porting a package (workflow)

Read the nixpkgs recipe → get the source archive hash (`nix store prefetch-file`) + the lock/deps → write `packages/<name>/package.nix` on the
matching constructor → compute the FOD hash from the build's `got:` line →
`nix build .#<name>` + `.#checks.<system>.fhs-<name>` → **revert on failure**
(`git checkout -- packages/<name>/package.nix`) to keep the tree green.

Recurring **real** blockers (not worth forcing): system C libs not pinned
(onnxruntime/alsa/libvips), workspace-member git deps (cargo), heavy native
bundles (keytar/sharp/torch-CUDA), sdist-C-compile (python), exotic build tools
(rusty_v8/cmake/`zig build`).

## Layout

`mk/` constructors · `vendor/` dep vendorers · `toolchains/` · `fetch/` (owned
fetch primitives) · `lib/` (meta helpers) · `packages/` (machinery packages) ·
`pins-*.nix` · `seed.nix` + `systems.nix` (the static bootstrap seed).
