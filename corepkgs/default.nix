# corepkgs — the nixpkgs-free packaging system, as an importable API.
#
#   core = import ./corepkgs { inherit system; }
#   core.lib.mkPackage { ... }   # the builder API
#   core.packages               # own buildable outputs (-bin toolchains + hello)
#
# Two seed layers are threaded through the scope as swappable providers (pins,
# toolchains); swap either for a from-source bootstrap without touching a
# constructor. `system` defaults to currentSystem so `nix build -f corepkgs
# --impure packages.hello` works.
{
  system ? builtins.currentSystem,
  pkgs ? null,
  # Pins from `pkgs` when given (root flake reuses its nixpkgs); otherwise the
  # nixpkgs-free provider that makes corepkgs a standalone no-input flake.
  # (pins/store.nix is the explicit impure fast-eval path.)
  pins ? if pkgs != null then import ./pins/pkgs.nix pkgs else import ./pins/closure.nix system,
  # The toolchain set, threaded through the scope like `pins`.
  toolchains ? import ./toolchains { inherit system pins; },
}:
let
  mkDrvNu = import ./mk/drv-nu.nix;
  # smoke test: a nixpkgs-free derivation with no toolchain at all.
  hello = mkDrvNu {
    inherit system;
    name = "hello";
    script = ''
      mkdir $"($out)/bin"
      "#!/bin/sh\necho hello from a nixpkgs-free derivation\n" | save --raw $"($out)/bin/hello"
      ^chmod +x $"($out)/bin/hello"
    '';
  };

  # Fetcher machinery (./fetch), nixpkgs-free: every fetch goes through
  # builtin:fetchurl and platformSource takes `system` directly (no stdenv), so
  # these work even on the standalone (pkgs = null) path.
  interpolate = import ./fetch/interpolate.nix;
  coreFetchurl = import ./fetch/fetchurl.nix;
  fetchurlTemplate = import ./fetch/fetchurl-template.nix {
    fetchurl = coreFetchurl;
    inherit interpolate;
  };
  platformSource = import ./fetch/platform-source.nix {
    inherit system fetchurlTemplate;
  };

  # Machinery packages (formatelf, wrapBuddy, buildNpmPackage,
  # versionCheckHomeHook): by-name package FUNCTIONS, un-called - the consumer
  # callPackage's them into its own scope. Exclude the `-bin` toolchain packages:
  # they take { system, pins } from the toolchains provider, not a callPackage
  # scope.
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
  # so a consumer's package.nix stays terse (just `mkPackage { ... }`).
  lib = {
    mkPackage = args: import ./mk/package.nix (args // { inherit system pins; });
    mkCargo = args: import ./mk/cargo.nix (args // { inherit system pins toolchains; });
    mkGo = args: import ./mk/go.nix (args // { inherit system pins toolchains; });
    mkNpm = args: import ./mk/npm.nix (args // { inherit system pins toolchains; });
    mkBun = args: import ./mk/bun.nix (args // { inherit system pins toolchains; });
    mkPnpm = args: import ./mk/pnpm.nix (args // { inherit system pins toolchains; });
    mkPython = args: import ./mk/python.nix (args // { inherit system pins toolchains; });
    mkDrvNu = args: import ./mk/drv-nu.nix (args // { inherit system; });
    mkDrvSh = args: import ./mk/drv-sh.nix (args // { inherit system; });
    checkFhs = args: import ./mk/check-fhs.nix (args // { inherit system pins; });
    inherit
      coreFetchurl
      interpolate
      fetchurlTemplate
      platformSource
      ;
    seed = import ./seed { inherit system; };
    systems = import ./seed/systems.nix;
    inherit pins system;

    # Meta helpers, un-called so the consumer supplies its own nixpkgs deps but
    # never path-imports a corepkgs file. mkUpdater { lib } validates a
    # passthru.updater config; mkUpdateScript { lib, writeShellApplication, ... }
    # builds its updateScript; flakeLib { inputs } is the extended nixpkgs lib
    # (custom maintainers/licenses).
    mkUpdater = import ./lib/mk-updater.nix;
    mkUpdateScript = import ./lib/mk-update-script.nix;
    flakeLib = import ./lib/maintainers.nix;
  };

  # Own buildable outputs: seed + -bin toolchains + hello (the -bin suffix marks
  # the prebuilt toolchain binaries; the provider maps them to logical names).
  # python is x86_64-linux only (manylinux lib pins). Linux only: systems.nix
  # carries no darwin toolchain rows (darwin has just the nushell seed).
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
