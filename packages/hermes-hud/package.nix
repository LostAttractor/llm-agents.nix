# hermes-hud - built from source on corepkgs (nixpkgs-free) via mkPython. pip
# builds the setuptools project into a site tree and resolves the runtime closure
# (pyyaml/textual/pyfiglet, all pure-python) from PyPI.
{
  mkPython,
  coreFetchurl,
  flake,
}:
mkPython {
  pname = "hermes-hud";
  version = "0.5.0";
  src = coreFetchurl {
    url = "https://github.com/joeynyc/hermes-hud/archive/refs/tags/v0.5.0.tar.gz";
    hash = "sha256-dC6PR/nlPJOKIs3JtUTJ1rHNGTlTRsx/EoyJsvFRBFw=";
  };
  pythonDepsHash = "sha256-e84Hk4Sf7dstI0+XpsbaEQk24bdyujxGG0DCv7fFbFM=";
  entrypoints.hermes-hud = "hermes_hud.hud:main";

  category = "AI Assistants";
  meta = {
    description = "TUI consciousness monitor for Hermes Agent";
    homepage = "https://github.com/joeynyc/hermes-hud";
    changelog = "https://github.com/joeynyc/hermes-hud/releases/tag/v0.5.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.smdex ];
  };
}
