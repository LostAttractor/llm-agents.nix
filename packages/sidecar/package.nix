# sidecar - built from source on corepkgs (nixpkgs-free) via mkGo. CGO_ENABLED=0,
# so the output is a fully static binary (no glibc, no patchelf). Modules are
# vendored by a single vendorHash FOD (go.sum hashes are not fetchurl-compatible).
{
  mkGo,
  coreFetchurl,
  flake,
}:
mkGo {
  pname = "sidecar";
  version = "0.99.1";
  src = coreFetchurl {
    url = "https://github.com/marcus/sidecar/archive/refs/tags/v0.99.1.tar.gz";
    hash = "sha256-+UflplKtSyu0IoP3nU8OWa/u1+burDfTKdxtIh6GnZQ=";
  };
  vendorHash = "sha256-TrUEkofD2a1An9OOBdLX3SH349BPzWqB10iPbs4Cou0=";
  subPackages = [ "cmd/sidecar" ];
  binaries = [ "sidecar" ];
  ldflags = [
    "-s"
    "-w"
    "-X=main.Version=0.99.1"
  ];

  category = "Workflow & Project Management";
  meta = {
    description = "Terminal-based development companion for AI coding agents";
    homepage = "https://github.com/marcus/sidecar";
    changelog = "https://github.com/marcus/sidecar/releases/tag/v0.99.1";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.afterthought ];
  };
}
