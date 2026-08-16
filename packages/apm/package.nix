# apm - built from source on corepkgs (nixpkgs-free) via mkPython. pip builds the
# setuptools project into a site tree and resolves the runtime closure (llm +
# llm-github-models + azure-ai-inference and their pure-python/manylinux deps)
# from PyPI; mkPython wraps the console script.
{
  mkPython,
  coreFetchurl,
  flake,
}:
mkPython {
  pname = "apm";
  version = "0.28.0";
  src = coreFetchurl {
    url = "https://github.com/microsoft/apm/archive/refs/tags/v0.28.0.tar.gz";
    hash = "sha256-cuAfSdY8uF8Iy1SxdfQau2OhnbdLw45GYjY/DHL/Eqo=";
  };
  pythonDepsHash = "sha256-o1YLVL5iY3s4gpicuFCcZVfV3cv7hpW2euHtZV28d4M=";
  entrypoints.apm = "apm_cli.cli:main";

  category = "Utilities";
  meta = {
    description = "Agent Package Manager — dependency manager for AI agents";
    homepage = "https://github.com/microsoft/apm";
    changelog = "https://github.com/microsoft/apm/releases/tag/v0.28.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
  };
}
