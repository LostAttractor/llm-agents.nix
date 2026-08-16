# mcptoon - built from source on corepkgs (nixpkgs-free) via mkPython. Zero
# runtime deps; pip builds the setuptools project into a site tree and mkPython
# wraps the console entry point on the naked CPython toolchain.
{
  mkPython,
  coreFetchurl,
  flake,
}:
mkPython {
  pname = "mcptoon";
  version = "0.4.1";
  src = coreFetchurl {
    url = "https://github.com/activeing123/mcptoon/archive/refs/tags/v0.4.1.tar.gz";
    hash = "sha256-wVj2Nn57opNxYojS/MO72m8FDIhFCmDFuBNZjsIDkGc=";
  };
  pythonDepsHash = "sha256-6NnsvvlZ4pFyAwB9pcaokkg7cfdojyQuZCUfy0XEv/g=";
  entrypoints.mcptoon = "mcptoon.cli:main";
  # upstream tags without bumping __version__; the CLI banner prints it.
  postPatch = ''sed -i -E 's/^__version__ = ".*"/__version__ = "0.4.1"/' src/mcptoon/__init__.py'';

  category = "Utilities";
  meta = {
    description = "Token-efficient MCP CLI client that converts tool discovery and results to compact TOON output";
    homepage = "https://github.com/activeing123/mcptoon";
    changelog = "https://github.com/activeing123/mcptoon/releases/tag/v0.4.1";
    license = flake.lib.licenses.asl20;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.zimbatm ];
  };
}
