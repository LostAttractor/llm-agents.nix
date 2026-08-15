# mardi-gras - built from source on corepkgs (nixpkgs-free) via mkGo.
# CGO_ENABLED=0, so the output is a fully static binary (no glibc, no patchelf).
# Modules are vendored by a single vendorHash FOD (go.sum hashes are not
# fetchurl-compatible).
{
  mkGo,
  coreFetchurl,
  flake,
}:
mkGo {
  pname = "mardi-gras";
  version = "0.28.1";
  src = coreFetchurl {
    url = "https://github.com/quietpublish/mardi-gras/archive/refs/tags/v0.28.1.tar.gz";
    hash = "sha256-gNi+/6jCPIeNeyRROUE8HY6UysBxJSGMhYtycBsWxbU=";
  };
  vendorHash = "sha256-/pe+fZDPsw4A6ZobeiR85VXDyzbB4pLfir9prInpLeo=";
  subPackages = [ "cmd/mg" ];
  binaries = [ "mg" ];
  ldflags = [
    "-s"
    "-w"
    "-X=main.version=0.28.1"
  ];

  category = "Workflow & Project Management";
  meta = {
    description = "Terminal UI for Beads issue tracking with a parade-inspired workflow view";
    homepage = "https://github.com/quietpublish/mardi-gras";
    changelog = "https://github.com/quietpublish/mardi-gras/releases/tag/v0.28.1";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.smdex ];
    mainProgram = "mg";
  };
}
