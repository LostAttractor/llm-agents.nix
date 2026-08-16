# gnhf - built from source on corepkgs (nixpkgs-free) via mkPnpm. pnpm deps
# vendored as a flat hoisted node_modules FOD; `pnpm run build` (tsdown) produces
# dist, and mkPnpm wraps `node dist/cli.mjs` on the naked node toolchain.
{
  mkPnpm,
  coreFetchurl,
  flake,
}:
mkPnpm {
  pname = "gnhf";
  version = "0.1.44";
  src = coreFetchurl {
    url = "https://github.com/kunchenguid/gnhf/archive/refs/tags/gnhf-v0.1.44.tar.gz";
    hash = "sha256-0e+B5aBK5Sc6DJIlhC9ifBKmQYLzvhiOL4yaG89fOzU=";
  };
  pnpmDepsHash = "sha256-SAMuDEW8CpKqkX+aOG1uheGBzUkvOnYm5+vMMBp0y6M=";
  entry = "dist/cli.mjs";

  category = "Workflow & Project Management";
  meta = {
    description = "Ralph/autoresearch-style orchestrator that keeps coding agents running while you sleep";
    homepage = "https://github.com/kunchenguid/gnhf";
    changelog = "https://github.com/kunchenguid/gnhf/releases/tag/gnhf-v0.1.44";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = with flake.lib.maintainers; [ pikdum ];
  };
}
