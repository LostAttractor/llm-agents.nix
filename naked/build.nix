# Shared builder: given a system + a pins set, produce the naked toolchains,
# x86_64 packages, and FHS checks. Two entrypoints feed it different pins:
#   default.nix  -> pins-store.nix (storePath; fast standalone eval, impure)
#   flake.nix    -> pins-pkgs.nix  (from pkgs; pure, so nixbot can build it)
let
  mkNaked = import ./mk-naked.nix;
  checkFhs = import ./check-fhs.nix;
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
      formatelf = import ./formatelf.nix { inherit system pins; };
      hello = mkNaked {
        inherit system;
        name = "naked-hello";
        script = ''
          mkdir -p "$out/bin"
          echo '#!/bin/sh' > "$out/bin/hello"
          echo 'echo hello from a nixpkgs-free derivation' >> "$out/bin/hello"
          chmod +x "$out/bin/hello"
        '';
      };
    };

  # binary-wrapper packages (x86_64-linux only: each needs per-arch release
  # hashes to go multi-arch).
  packages =
    pins:
    let
      system = "x86_64-linux";
      mk = name: import (./packages + "/${name}.nix") { inherit system pins; };
    in
    {
      amp = mk "amp";
      cursor-agent = mk "cursor-agent";
      eca = mk "eca";
      droid = mk "droid";
      grok = mk "grok";
      coderabbit-cli = mk "coderabbit-cli";
      cubic = mk "cubic";
      forgecode = mk "forgecode";
      open-code-review = mk "open-code-review";
      jules = mk "jules";
      kilocode-cli = mk "kilocode-cli";
    };

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
