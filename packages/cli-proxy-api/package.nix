# cli-proxy-api - built from source on corepkgs (nixpkgs-free) via mkGo.
# CGO_ENABLED=0, so the output is a fully static binary (no glibc, no patchelf).
# Modules are vendored by a single vendorHash FOD.
{
  mkGo,
  coreFetchurl,
  flake,
}:
mkGo {
  pname = "cli-proxy-api";
  version = "7.2.132";
  src = coreFetchurl {
    url = "https://github.com/router-for-me/CLIProxyAPI/archive/refs/tags/v7.2.132.tar.gz";
    hash = "sha256-MR9jlA3IfZ+5ychuxuN5Ujai1fPbfsLQ/icxHOggHkw=";
  };
  vendorHash = "sha256-CrDp7MOr+AwJUhTovklXx3F1yaktQlvD7VYhYSY6VvY=";
  subPackages = [ "cmd/server" ];
  binaries = [ "cli-proxy-api" ];
  ldflags = [
    "-s"
    "-w"
    "-X main.Version=7.2.132"
    "-X main.Commit=nixpkgs"
    "-X main.BuildDate=1970-01-01T00:00:00Z"
  ];

  category = "Utilities";
  meta = {
    description = "Unified proxy providing OpenAI/Gemini/Claude/Codex compatible APIs for AI coding CLI tools";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    changelog = "https://github.com/router-for-me/CLIProxyAPI/releases";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.odysseus0 ];
  };
}
