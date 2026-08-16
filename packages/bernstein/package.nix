# bernstein - built from source on corepkgs (nixpkgs-free) via mkPython. pip
# builds the hatchling project into a site tree and resolves the runtime closure
# (fastapi/uvicorn/cryptography/pillow/reportlab/... manylinux + pure-python
# wheels) from PyPI; mkPython wraps the three console entry points.
{
  mkPython,
  coreFetchurl,
  flake,
}:
mkPython {
  pname = "bernstein";
  version = "3.15.1";
  src = coreFetchurl {
    url = "https://github.com/sipyourdrink-ltd/bernstein/archive/refs/tags/v3.15.1.tar.gz";
    hash = "sha256-jwnfeGTwGYvK6LXrVWCmFNDqpdQmzHaLMSMKOfZmh14=";
  };
  pythonDepsHash = "sha256-or3A8luJXLlw+5fdPX8wdzql1VP966GMDkh7726pTak=";
  entrypoints = {
    bernstein = "bernstein.cli.main:cli";
    bernstein-worker = "bernstein.core.worker:main";
    bernstein-bench = "bernstein.eval.bench.bench_cli:bench_group";
  };
  mainProgram = "bernstein";
  # Align the pyproject version with the tag, and drop the hatch build exclude
  # list. Older wheels stripped core/ sub-packages the lazy-import finder in
  # core/__init__.py still references at runtime; removing the exclude keeps the
  # full package tree in the installed site.
  postPatch = ''
    sed -i -E 's/^version = ".*"/version = "3.15.1"/' pyproject.toml
    sed -i '/^exclude = \[/,/^\]/d' pyproject.toml
  '';

  category = "Workflow & Project Management";
  meta = {
    description = "Multi-agent orchestrator for CLI coding agents — spawn, coordinate, and manage parallel AI agents";
    homepage = "https://github.com/sipyourdrink-ltd/bernstein";
    changelog = "https://github.com/sipyourdrink-ltd/bernstein/releases/tag/v3.15.1";
    license = flake.lib.licenses.asl20;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.chernistry ];
  };
}
