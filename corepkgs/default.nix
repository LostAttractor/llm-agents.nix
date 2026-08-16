# corepkgs — the nixpkgs-free packaging system, as an importable API.
#
#   core = import ./corepkgs { inherit system; }          # nixpkgs-free
#   core.lib.mkBinary { ... }      # the builder API
#   core.packages                  # corepkgs' own buildable outputs (-bin toolchains + hello)
#
# The two seed layers are threaded through the scope as swappable providers:
#   pins       — prebuilt C libraries + tools (glibc, openssl, formatelf, ...).
#                Default: the nixpkgs-free fetchClosure provider (pins-closure);
#                when `pkgs` is passed (root flake), pins/pkgs.nix reuses it.
#   toolchains — the compilers/runtimes we build WITH (rust, go, node, ...).
#                Default: fetched prebuilt (toolchains/default.nix).
# Swap either provider (e.g. a from-source bootstrap) without touching a
# constructor. `system` defaults to the current system so `nix build -f corepkgs
# --impure packages.hello` still works.
{
  system ? builtins.currentSystem,
  pkgs ? null,
  # Pins: from `pkgs` when given (pins/pkgs.nix, so the root flake reuses its own
  # nixpkgs). Otherwise the pure, nixpkgs-free fetchClosure provider - which is
  # what makes corepkgs a standalone flake with no nixpkgs input. (pins/store.nix
  # remains for an explicit impure fast-eval path: `import ./pins/store.nix`.)
  pins ? if pkgs != null then import ./pins/pkgs.nix pkgs else import ./pins/closure.nix system,
  # The toolchain set (seed, zig, bun, node, rust, go, python), threaded through
  # the constructor scope like `pins`. Swap this provider to change the bootstrap
  # (fetched-prebuilt -> from-source) without touching any constructor.
  toolchains ? import ./toolchains { inherit system pins; },
}:
let
  mkNaked = import ./mk/naked.nix;
  # smoke-test package: a nixpkgs-free derivation with no toolchain at all.
  hello = mkNaked {
    inherit system;
    name = "naked-hello";
    script = ''
      mkdir $"($out)/bin"
      "#!/bin/sh\necho hello from a nixpkgs-free derivation\n" | save --raw $"($out)/bin/hello"
      ^chmod +x $"($out)/bin/hello"
    '';
  };

  # All fetcher machinery lives together in ./fetch and is nixpkgs-free: every
  # fetch goes through the naked builtin:fetchurl fetcher, and platformSource
  # takes the `system` string directly (no stdenv). So these are always
  # available, even on the standalone (pkgs = null) path.
  interpolate = import ./fetch/interpolate.nix;
  coreFetchurl = import ./fetch/fetchurl.nix;
  nakedFetchurl = import ./fetch/naked-fetchurl.nix;
  fetchurlTemplate = import ./fetch/fetchurl-template.nix {
    fetchurl = nakedFetchurl;
    inherit interpolate;
  };
  platformSource = import ./fetch/platform-source.nix {
    inherit system fetchurlTemplate;
  };

  # corepkgs' own machinery packages (formatelf, wrapBuddy, buildNpmPackage,
  # versionCheckHomeHook): the by-name package FUNCTIONS, un-called. corepkgs
  # owns their location; a consumer callPackage's them into its own scope, so it
  # never has to readDir or path-import corepkgs/packages itself. The `-bin`
  # toolchain packages (bun-bin, rust-bin, ...) also live in ./packages but are
  # NOT machinery: they take { system, pins } (built by the toolchains provider),
  # not the consumer's callPackage scope, so exclude them here.
  machinery =
    let
      entries = builtins.readDir ./packages;
      dirs = builtins.filter (n: entries.${n} == "directory" && builtins.match ".*-bin" n == null) (
        builtins.attrNames entries
      );
    in
    builtins.listToAttrs (
      map (n: {
        name = n;
        value = import (./packages + "/${n}/package.nix");
      }) dirs
    );
in
{
  inherit
    system
    pins
    toolchains
    machinery
    ;

  # The builder API: constructors + owned primitives, with system/pins pre-bound
  # so a consumer's package.nix stays terse (just `mkBinary { ... }`).
  lib = {
    mkBinary = args: import ./mk/binary.nix (args // { inherit system pins; });
    mkCargo = args: import ./mk/cargo.nix (args // { inherit system pins toolchains; });
    mkGo = args: import ./mk/go.nix (args // { inherit system pins toolchains; });
    mkNpm = args: import ./mk/npm.nix (args // { inherit system pins toolchains; });
    mkBun = args: import ./mk/bun.nix (args // { inherit system pins toolchains; });
    mkPnpm = args: import ./mk/pnpm.nix (args // { inherit system pins toolchains; });
    mkPython = args: import ./mk/python.nix (args // { inherit system pins toolchains; });
    mkNaked = args: import ./mk/naked.nix (args // { inherit system; });
    mkNakedSh = args: import ./mk/naked-sh.nix (args // { inherit system; });
    checkFhs = args: import ./mk/check-fhs.nix (args // { inherit system pins; });
    inherit
      coreFetchurl
      interpolate
      nakedFetchurl
      fetchurlTemplate
      platformSource
      ;
    seed = import ./seed { inherit system; };
    systems = import ./seed/systems.nix;
    inherit pins system;

    # Meta helpers, exposed as un-called functions so the consumer supplies its
    # own nixpkgs deps (lib, updater tools, flake inputs) but never path-imports
    # a corepkgs file. mkUpdater { lib } validates a passthru.updater config;
    # mkUpdateScript { lib, writeShellApplication, ... } builds its updateScript;
    # flakeLib { inputs } is the extended nixpkgs lib (custom maintainers/licenses).
    mkUpdater = import ./lib/mk-updater.nix;
    mkUpdateScript = import ./lib/mk-update-script.nix;
    flakeLib = import ./lib/maintainers.nix;
  };

  # corepkgs' own buildable outputs: the seed + the -bin toolchains + hello (the
  # toolchain packages carry the -bin suffix, being prebuilt binaries; the
  # provider maps them to logical names for the constructors). python on
  # x86_64-linux only (its manylinux lib pins are x86_64). Linux only: the
  # toolchains fetch per-arch from systems.nix, which carries only Linux rows
  # (darwin has just the nushell seed; darwin agent packages pull it directly).
  packages =
    if system == "x86_64-linux" || system == "aarch64-linux" then
      {
        inherit (toolchains) seed;
        bun-bin = toolchains.bun;
        node-bin = toolchains.node;
        zig-bin = toolchains.zig;
        go-bin = toolchains.go;
        rust-bin = toolchains.rust;
        pnpm-bin = toolchains.pnpm;
        inherit hello;
      }
      // (if system == "x86_64-linux" then { python-bin = toolchains.python; } else { })
    else
      { };
}
