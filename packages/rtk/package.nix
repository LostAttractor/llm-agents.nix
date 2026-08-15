# rtk - built from source on corepkgs (nixpkgs-free) via mkCargo. rusqlite's
# bundled sqlite C compiles via zig cc. (Upstream wraps shell hooks with jq in a
# postInstall; that is dropped here - cosmetic, not a build concern.)
{
  mkCargo,
  coreFetchurl,
  flake,
}:
mkCargo {
  pname = "rtk";
  version = "0.45.0";
  src = coreFetchurl {
    url = "https://github.com/rtk-ai/rtk/archive/refs/tags/v0.45.0.tar.gz";
    hash = "sha256-BFn2PLefYQdRl0uiBzLic9Rd27TNDAeVdotiuGiJGtk=";
  };
  cargoLock = ./Cargo.lock;
  binaries = [ "rtk" ];

  category = "Utilities";
  meta = {
    description = "CLI proxy that reduces LLM token consumption by 60-90% on common dev commands";
    homepage = "https://github.com/rtk-ai/rtk";
    changelog = "https://github.com/rtk-ai/rtk/releases/tag/v0.45.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.vizid ];
  };
}
