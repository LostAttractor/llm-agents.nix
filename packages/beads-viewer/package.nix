# beads-viewer - built from source on corepkgs (nixpkgs-free) via mkGo, static
# (CGO_ENABLED=0). No external deps (stdlib only), so no vendorHash.
{
  mkGo,
  coreFetchurl,
  flake,
}:
mkGo {
  pname = "beads-viewer";
  version = "0.19.0";
  src = coreFetchurl {
    url = "https://github.com/Dicklesworthstone/beads_viewer/archive/refs/tags/v0.19.0.tar.gz";
    hash = "sha256-dFnuqpmXa+eOoKn4Xx25jicBF3KoDKXsBdISXg+Gzgo=";
  };
  subPackages = [ "cmd/bv" ];
  binaries = [ "bv" ];
  ldflags = [
    "-s"
    "-w"
    "-X github.com/Dicklesworthstone/beads_viewer/pkg/version.version=v0.19.0"
  ];
  category = "Workflow & Project Management";
  meta = {
    description = "Graph-aware TUI for the Beads issue tracker";
    homepage = "https://github.com/Dicklesworthstone/beads_viewer";
    changelog = "https://github.com/Dicklesworthstone/beads_viewer/releases/tag/v0.19.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.afterthought ];
  };
}
