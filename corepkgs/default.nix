# corepkgs — the nixpkgs-free packaging system, as an importable API.
#
#   core = import ./corepkgs { inherit system; pkgs = <nixpkgs for system>; };
#   core.lib.mkBinary { ... }      # the builder API
#   core.packages                  # corepkgs' own machinery (toolchains, formatelf, hello)
#
# Pins come from `pkgs` (pure, pins-pkgs.nix) when it is given, else from
# storePath pins (pins-store.nix; fast standalone eval, but impure). The root
# flake passes `pkgs` so its outputs stay pure; corepkgs/flake.nix (a real,
# standalone flake) does the same. `system` defaults to the current system so
# `nix build -f corepkgs --impure packages.hello` still works.
{
  system ? builtins.currentSystem,
  pkgs ? null,
  # Pins: from `pkgs` when given (pins-pkgs.nix, so the root flake reuses its own
  # nixpkgs). Otherwise the pure, nixpkgs-free fetchClosure provider - which is
  # what makes corepkgs a standalone flake with no nixpkgs input. (pins-store.nix
  # remains for an explicit impure fast-eval path: `import ./pins-store.nix`.)
  pins ? if pkgs != null then import ./pins-pkgs.nix pkgs else import ./pins-closure.nix system,
}:
let
  build = import ./build.nix;

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
in
{
  inherit system pins;

  # The builder API: constructors + owned primitives, with system/pins pre-bound
  # so a consumer's package.nix stays terse (just `mkBinary { ... }`).
  lib = {
    mkBinary = args: import ./mk/binary.nix (args // { inherit system pins; });
    mkCargo = args: import ./mk/cargo.nix (args // { inherit system pins; });
    mkGo = args: import ./mk/go.nix (args // { inherit system pins; });
    mkNpm = args: import ./mk/npm.nix (args // { inherit system pins; });
    mkPython = args: import ./mk/python.nix (args // { inherit system pins; });
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
    seed = import ./seed.nix { inherit system; };
    systems = import ./systems.nix;
    inherit pins system;
  };

  # corepkgs' own machinery packages: the seed + toolchains + formatelf + hello,
  # plus python on x86_64-linux (its manylinux lib pins are x86_64). These are
  # the "utils" that live in corepkgs, not agent output. Linux only: the
  # toolchains (bun/node/rust/zig) fetch per-arch from systems.nix, which today
  # carries only Linux rows (darwin has just the nushell seed). Darwin agent
  # packages still build fine — they pull the darwin seed directly.
  packages =
    if system == "x86_64-linux" then
      build.toolchains { inherit system pins; } // { python = build.python pins; }
    else if system == "aarch64-linux" then
      build.toolchains { inherit system pins; }
    else
      { };
}
