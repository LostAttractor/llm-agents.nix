# Shared builder: given a system + a pins set, produce the naked toolchains,
# x86_64 packages, and FHS checks. Two entrypoints feed it different pins:
#   default.nix  -> pins-store.nix (storePath; fast standalone eval, impure)
#   flake.nix    -> pins-pkgs.nix  (from pkgs; pure, so nixbot can build it)
let
  mkNaked = import ./mk/naked.nix;
  checkFhs = import ./mk/check-fhs.nix;
in
{
  toolchains =
    { system, pins }:
    {
      seed = import ./seed.nix { inherit system; };
      bun = import ./toolchains/bun.nix { inherit system pins; };
      node = import ./toolchains/node.nix { inherit system pins; };
      rust = import ./toolchains/rust.nix { inherit system pins; };
      zig = import ./toolchains/zig.nix { inherit system; };
      go = import ./toolchains/go.nix { inherit system pins; };
      hello = mkNaked {
        inherit system;
        name = "naked-hello";
        script = ''
          mkdir $"($out)/bin"
          "#!/bin/sh\necho hello from a nixpkgs-free derivation\n" | save --raw $"($out)/bin/hello"
          ^chmod +x $"($out)/bin/hello"
        '';
      };
    };

  # python toolchain (x86_64-linux only: its manylinux lib pins are x86_64)
  python =
    pins:
    import ./toolchains/python.nix {
      system = "x86_64-linux";
      inherit pins;
    };

  # binary-wrapper packages (x86_64-linux only). Auto-discovered from
  # ./packages/*.nix so porting a package = dropping a file, no wiring.
  packages =
    pins:
    let
      system = "x86_64-linux";
      names = builtins.filter (n: builtins.match "(.*)\\.nix" n != null) (
        builtins.attrNames (builtins.readDir ./packages)
      );
      base = n: builtins.head (builtins.match "(.*)\\.nix" n);
    in
    builtins.listToAttrs (
      map (n: {
        name = base n;
        value = import (./packages + "/${n}") { inherit system pins; };
      }) names
    );

  checks =
    pins: pkgSet:
    builtins.mapAttrs (
      name: package:
      checkFhs {
        system = "x86_64-linux";
        inherit pins package name;
      }
    ) pkgSet;
}
