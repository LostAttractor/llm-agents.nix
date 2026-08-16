# spec-kit - built from source on corepkgs (nixpkgs-free) via mkPython. pip
# builds the hatchling project into a site tree and resolves the runtime closure
# (typer/rich/httpx/... all pure-python or manylinux wheels) from PyPI.
{
  mkPython,
  coreFetchurl,
  flake,
}:
mkPython {
  pname = "spec-kit";
  version = "0.16.4";
  src = coreFetchurl {
    url = "https://github.com/github/spec-kit/archive/refs/tags/v0.16.4.tar.gz";
    hash = "sha256-ABLkwblWKEtChMrpuY7phPenG89h0tCv8XmCTrIv84c=";
  };
  pythonDepsHash = "sha256-+qTnEJpx2QWfdc5tcLYCMUEsF4fh+ZvKw5DOQ4OzZ5o=";
  entrypoints.specify = "specify_cli:main";
  mainProgram = "specify";

  category = "Workflow & Project Management";
  meta = {
    description = "Specify CLI, part of GitHub Spec Kit. A tool to bootstrap your projects for Spec-Driven Development (SDD)";
    homepage = "https://github.com/github/spec-kit";
    changelog = "https://github.com/github/spec-kit/releases/tag/v0.16.4";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
  };
}
