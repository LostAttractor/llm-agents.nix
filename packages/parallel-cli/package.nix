# parallel-cli - built from source on corepkgs (nixpkgs-free) via mkPython. pip
# builds the hatchling project into a site tree and resolves the base runtime
# closure (parallel-web + manylinux/pure-python deps) from PyPI; mkPython wraps
# the console script. The optional data-integration extras (polars, duckdb,
# snowflake, bigquery) are not installed by the base `pip install .`.
{
  mkPython,
  coreFetchurl,
  flake,
}:
mkPython {
  pname = "parallel-cli";
  version = "0.9.2";
  src = coreFetchurl {
    url = "https://github.com/parallel-web/parallel-web-tools/archive/refs/tags/v0.9.2.tar.gz";
    hash = "sha256-lFOfzbWK8yl6Mgabc7XhEmvblUcyICUbCgVhDOrB/tE=";
  };
  pythonDepsHash = "sha256-N0KZ0wXexALgaIqQujdHqs4tXoHqNnBfwoP5ygdmk9k=";
  entrypoints.parallel-cli = "parallel_web_tools.cli:main";

  category = "Utilities";
  meta = {
    description = "AI-powered web search, extraction, and research CLI from Parallel";
    homepage = "https://github.com/parallel-web/parallel-web-tools";
    changelog = "https://github.com/parallel-web/parallel-web-tools/releases/tag/v0.9.2";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.SecBear ];
  };
}
