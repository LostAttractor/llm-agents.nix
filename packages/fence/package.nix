# fence - built from source on corepkgs (nixpkgs-free) via mkGo. CGO_ENABLED=0,
# so the output is a fully static binary (no glibc, no patchelf). Modules are
# vendored by a single vendorHash FOD (go.sum hashes are not fetchurl-compatible).
{
  mkGo,
  coreFetchurl,
  flake,
}:
mkGo {
  pname = "fence";
  version = "0.1.66";
  src = coreFetchurl {
    url = "https://github.com/fencesandbox/fence/archive/refs/tags/v0.1.66.tar.gz";
    hash = "sha256-ps5FglS6jXS4T0D16ZvS+I/S5xyKfKCWLjJgwLbW/K8=";
  };
  vendorHash = "sha256-WjhfAw8wgxvTbTkYwURm9vN2oSvQWiMP2RhwZDCQ0DU=";
  subPackages = [ "cmd/fence" ];
  binaries = [ "fence" ];
  ldflags = [
    "-s"
    "-w"
    "-X=main.version=0.1.66"
    "-X=main.buildTime=1970-01-01T00:00:00Z"
    "-X=main.gitCommit=v0.1.66"
  ];

  category = "Sandboxing & Isolation";
  meta = {
    description = "Lightweight, container-free sandbox for running commands with network and filesystem restrictions";
    homepage = "https://fencesandbox.com/";
    changelog = "https://github.com/fencesandbox/fence/releases";
    license = flake.lib.licenses.asl20;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.uesyn ];
    mainProgram = "fence";
  };
}
