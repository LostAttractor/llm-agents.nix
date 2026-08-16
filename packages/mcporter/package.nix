# mcporter - built from source on corepkgs (nixpkgs-free) via mkPnpm. pnpm deps
# vendored as a flat hoisted node_modules FOD; `pnpm run build` (tsc) produces
# dist, and mkPnpm wraps `node dist/cli.js` on the naked node toolchain.
{
  mkPnpm,
  coreFetchurl,
  flake,
}:
mkPnpm {
  pname = "mcporter";
  version = "0.13.7";
  src = coreFetchurl {
    url = "https://github.com/openclaw/mcporter/archive/refs/tags/v0.13.7.tar.gz";
    hash = "sha256-EajnDVMaIQt0BYPooZLAsJz5zaXJFIGNBot9BEhAUY8=";
  };
  pnpmDepsHash = "sha256-wzkkbtvpTt1rUB8W0Mm36cbRzMT5pNVlosGajuEG5ss=";
  entry = "dist/cli.js";
  # upstream's lockfile predates the pnpm.overrides vite entry; align the
  # specifier so pnpm accepts the frozen lockfile.
  postPatch = ''sed -i 's/specifier: \^8\.0\.8/specifier: 8.0.8/' pnpm-lock.yaml'';

  category = "Utilities";
  meta = {
    description = "TypeScript runtime and CLI for the Model Context Protocol";
    homepage = "https://github.com/openclaw/mcporter";
    changelog = "https://github.com/openclaw/mcporter/releases";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ ];
  };
}
