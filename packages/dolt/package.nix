# dolt - built from source on corepkgs (nixpkgs-free) via mkGo with cgo (it
# links ICU via cgo). zig cc compiles the cgo C; the dynamic output is patchelf'd
# to the pinned glibc + icu. buildInputs pass icu (lib for rpath) + icuDev
# (pkgconfig/headers for the #cgo pkg-config). go.mod lives in ./go.
{
  mkGo,
  coreFetchurl,
  corePins,
  flake,
}:
mkGo {
  pname = "dolt";
  version = "2.3.0";
  src = coreFetchurl {
    url = "https://github.com/dolthub/dolt/archive/refs/tags/v2.3.0.tar.gz";
    hash = "sha256-h6ttuaCH5qfoDT96eeKj30ioTlZjmbMlDrerCg8FKyc=";
  };
  vendorHash = "sha256-/DEfQ1s+03/IEz1emrCslQsIF04pR6V3I+rGK/AeyKE=";
  cgo = true;
  buildInputs = [
    corePins.icu
    corePins.icuDev
  ];
  sourceRoot = "go";
  subPackages = [ "cmd/dolt" ];
  binaries = [ "dolt" ];
  ldflags = [ "-buildid=" ];
  category = "Utilities";
  meta = {
    description = "Relational database with version control and CLI a-la Git";
    homepage = "https://github.com/dolthub/dolt";
    changelog = "https://github.com/dolthub/dolt/releases/tag/v2.3.0";
    license = flake.lib.licenses.asl20;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
  };
}
