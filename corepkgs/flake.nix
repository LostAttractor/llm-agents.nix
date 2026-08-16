# corepkgs as a standalone flake — so `nix build ./corepkgs#packages.<system>.hello`
# (or formatelf, bun, ...) works on its own. The root llm-agents.nix flake does
# NOT consume this; it imports ./default.nix directly (core.lib.mkPackage), which
# keeps eval fast and avoids a locked path input. This flake is purely for using
# corepkgs by itself.
#
# corepkgs has NO nixpkgs input: pins come from pins/closure.nix (appendContext of
# stock cache.nixos.org / cache.numtide.com paths - pure + nixpkgs-free), and
# every toolchain/package fetches its upstream artifact via coreFetchurl. So this
# flake needs no inputs at all.
{
  description = "corepkgs — a nixpkgs-free packaging system (static seed + nushell builder)";

  outputs =
    { ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      # local genAttrs so we need no nixpkgs.lib
      eachSystem =
        f:
        builtins.listToAttrs (
          map (s: {
            name = s;
            value = f s;
          }) systems
        );
      # pkgs omitted -> default.nix uses the nixpkgs-free fetchClosure pins
      coreFor = system: import ./. { inherit system; };
    in
    {
      lib = eachSystem (system: (coreFor system).lib);
      packages = eachSystem (system: (coreFor system).packages);
    };
}
