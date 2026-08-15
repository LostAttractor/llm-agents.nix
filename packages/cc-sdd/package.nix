# cc-sdd - built from source on corepkgs (nixpkgs-free) via mkNpm. TypeScript CLI
# (npm run build -> tsc -> dist/cli.js). Deps vendored as a node_modules FOD.
{
  mkNpm,
  coreFetchurl,
  flake,
}:
mkNpm {
  pname = "cc-sdd";
  version = "3.0.2";
  src = coreFetchurl {
    url = "https://github.com/gotalab/cc-sdd/archive/refs/tags/v3.0.2.tar.gz";
    hash = "sha256-pAXImgcNin29mHU9QKw1bQzGH0KM5F/np3ZZojktyxg=";
  };
  npmDepsHash = "sha256-NwT8M7R2p5ycDRUaE0KijAwBr3/Sd/FYl2lE91gw+UU=";
  sourceRoot = "tools/cc-sdd";
  category = "Workflow & Project Management";
  meta = {
    description = "Bring spec-driven development to Claude Code, Cursor, Gemini CLI and other AI coding agents";
    homepage = "https://github.com/gotalab/cc-sdd";
    changelog = "https://github.com/gotalab/cc-sdd/releases/tag/v3.0.2";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.ryoppippi ];
  };
}
