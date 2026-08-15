# gascity - built from source on corepkgs (nixpkgs-free) via mkGo. CGO_ENABLED=0,
# so the output is a fully static binary (no glibc, no patchelf). Modules are
# vendored by a single vendorHash FOD (go.sum hashes are not fetchurl-compatible).
{
  mkGo,
  coreFetchurl,
  flake,
}:
mkGo {
  pname = "gascity";
  version = "1.4.0";
  src = coreFetchurl {
    url = "https://github.com/gastownhall/gascity/archive/refs/tags/v1.4.0.tar.gz";
    hash = "sha256-48Dp6W4eymN6iUhH4FJby1xG7c1ozpbAJtS0U+RgR1Y=";
  };
  vendorHash = "sha256-zJTfOU5IvRZTQUFQrqqjN+/bCWflCZBMjWNbHJZC6PQ=";
  subPackages = [ "cmd/gc" ];
  binaries = [ "gc" ];
  ldflags = [
    "-s"
    "-w"
    "-X=main.version=1.4.0"
    "-X=main.commit=nixpkgs"
    "-X=main.date=1970-01-01T00:00:00Z"
  ];

  category = "Workflow & Project Management";
  meta = {
    description = "Orchestration-builder SDK for multi-agent coding workflows";
    homepage = "https://github.com/gastownhall/gascity";
    changelog = "https://github.com/gastownhall/gascity/releases/tag/v1.4.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.zaninime ];
    mainProgram = "gc";
  };
}
