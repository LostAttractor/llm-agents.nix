# td - built from source on corepkgs (nixpkgs-free) via mkGo. CGO_ENABLED=0,
# so the output is a fully static binary (no glibc, no patchelf). Modules are
# vendored by a single vendorHash FOD (go.sum hashes are not fetchurl-compatible).
{
  mkGo,
  coreFetchurl,
  flake,
}:
mkGo {
  pname = "td";
  version = "0.57.0";
  src = coreFetchurl {
    url = "https://github.com/marcus/td/archive/refs/tags/v0.57.0.tar.gz";
    hash = "sha256-rTRQyK8DkERlVgk66UqXs4JAB8CY+FUtHQBGd1rXDSY=";
  };
  vendorHash = "sha256-/IWBYL+WfLz7vDdUs//0KY8rb9mOv4S1jBXCZbYxJRo=";
  binaries = [ "td" ];
  ldflags = [
    "-s"
    "-w"
    "-X=main.Version=0.57.0"
  ];

  category = "Workflow & Project Management";
  meta = {
    description = "A minimalist CLI for tracking tasks across AI coding sessions.";
    homepage = "https://github.com/marcus/td";
    changelog = "https://github.com/marcus/td/releases/tag/v0.57.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.afterthought ];
  };
}
