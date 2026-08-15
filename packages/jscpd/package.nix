# jscpd - built from source on corepkgs (nixpkgs-free) via mkCargo. The rust
# workspace lives in the rust/ subdir (sourceRoot) and we build just the jscpd
# binary crate (-p jscpd). Pure crates.io, no git deps.
{
  mkCargo,
  coreFetchurl,
  flake,
}:
mkCargo {
  pname = "jscpd";
  version = "5.0.15";
  src = coreFetchurl {
    url = "https://github.com/kucherenko/jscpd/archive/refs/tags/v5.0.15.tar.gz";
    hash = "sha256-F5Z1CjMEEpBClLUDajFnfmcLWWEXxZhvEJGluInsNIs=";
  };
  cargoLock = ./Cargo.lock;
  sourceRoot = "rust";
  cargoBuildFlags = [
    "-p"
    "jscpd"
  ];
  binaries = [ "jscpd" ];

  category = "Code Review";
  meta = {
    description = "Copy/paste detector for programming source code";
    homepage = "https://jscpd.dev";
    changelog = "https://github.com/kucherenko/jscpd/releases/tag/v5.0.15";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.mic92 ];
  };
}
