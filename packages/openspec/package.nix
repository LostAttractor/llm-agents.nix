# openspec - built on corepkgs (nixpkgs-free) via mkNpm. Prebuilt-dist npm
# package (registry tgz, dontNpmBuild); node_modules vendored from the committed
# package-lock.json (the tgz ships none, so inject it - like the nixpkgs recipe).
{
  mkNpm,
  coreFetchurl,
  flake,
}:
mkNpm {
  pname = "openspec";
  version = "1.9.0";
  src = coreFetchurl {
    url = "https://registry.npmjs.org/@fission-ai/openspec/-/openspec-1.9.0.tgz";
    hash = "sha256-wxt5LRQ3piuU+/97M4ibSmQR0Ib6LB/lUKoU93xRWyw=";
  };
  packageLock = ./package-lock.json;
  npmDepsHash = "sha256-cSNxDuQttA5CGr7mM8ZBDPj8TQvf4Gnjp2wIUG2E79w=";
  buildScript = "";
  category = "Workflow & Project Management";
  meta = {
    description = "Spec-driven development for AI coding assistants";
    homepage = "https://github.com/Fission-AI/OpenSpec";
    changelog = "https://github.com/Fission-AI/OpenSpec/releases/tag/v1.9.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.binaryBytecode ];
    maintainers = [ ];
  };
}
