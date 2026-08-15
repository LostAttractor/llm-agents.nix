# showboat - built from source on corepkgs (nixpkgs-free) via mkGo. CGO_ENABLED=0,
# so the output is a fully static binary (no glibc, no patchelf). Modules are
# vendored by a single vendorHash FOD (go.sum hashes are not fetchurl-compatible).
{
  mkGo,
  coreFetchurl,
  flake,
}:
mkGo {
  pname = "showboat";
  version = "0.6.1";
  src = coreFetchurl {
    url = "https://github.com/simonw/showboat/archive/refs/tags/v0.6.1.tar.gz";
    hash = "sha256-Tv8kyJffheODMW49ZSwD0X1ojfMpxEQ9K9cMq6J3N50=";
  };
  vendorHash = "sha256-mGKxBRU5TPgdmiSx0DHEd0Ys8gsVD/YdBfbDdSVpC3U=";
  binaries = [ "showboat" ];
  ldflags = [
    "-s"
    "-w"
    "-X=main.version=0.6.1"
  ];

  category = "Utilities";
  meta = {
    description = "Create executable demo documents showing and proving an agent's work";
    homepage = "https://github.com/simonw/showboat";
    changelog = "https://github.com/simonw/showboat/releases/tag/v0.6.1";
    license = flake.lib.licenses.asl20;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.jfroche ];
  };
}
