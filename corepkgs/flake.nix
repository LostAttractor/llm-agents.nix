# corepkgs as a standalone flake — so `nix build ./corepkgs#packages.<system>.hello`
# (or formatelf, bun, ...) works on its own. The root llm-agents.nix flake does
# NOT consume this; it imports ./default.nix directly (core.lib.mkBinary), which
# keeps eval fast and avoids a locked path input. This flake is purely for using
# corepkgs by itself.
{
  description = "corepkgs — a nixpkgs-free packaging system (static seed + nushell builder)";

  inputs."nixpkgs".url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  # `...` accepts the `self` Nix always passes without deadnix stripping it.
  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      eachSystem = nixpkgs.lib.genAttrs systems;
      coreFor =
        system:
        import ./. {
          inherit system;
          pkgs = nixpkgs.legacyPackages.${system};
        };
    in
    {
      lib = eachSystem (system: (coreFor system).lib);
      packages = eachSystem (system: (coreFor system).packages);
    };
}
