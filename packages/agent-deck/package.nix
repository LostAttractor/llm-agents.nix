# agent-deck - built from source on corepkgs (nixpkgs-free) via mkGo.
# CGO_ENABLED=0, so the output is a fully static binary (no glibc, no patchelf).
# Modules are vendored by a single vendorHash FOD.
{
  mkGo,
  coreFetchurl,
  flake,
}:
mkGo {
  pname = "agent-deck";
  version = "1.11.0";
  src = coreFetchurl {
    url = "https://github.com/asheshgoplani/agent-deck/archive/refs/tags/v1.11.0.tar.gz";
    hash = "sha256-+VzpVBzTdJ+6N268s/G9E+tVVw9g9v8NXEOpWnQJEqs=";
  };
  vendorHash = "sha256-rLhOjYfLAPPRTfLFPMlxrjSSqmHFmPoXPFZbaevEgtw=";
  subPackages = [ "cmd/agent-deck" ];
  binaries = [ "agent-deck" ];
  ldflags = [
    "-s"
    "-w"
    "-X=main.Version=1.11.0"
  ];

  category = "Workflow & Project Management";
  meta = {
    description = "Your AI agent command center";
    homepage = "https://github.com/asheshgoplani/agent-deck";
    changelog = "https://github.com/asheshgoplani/agent-deck/releases/tag/v1.11.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.garbas ];
  };
}
