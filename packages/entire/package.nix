# entire - built from source on corepkgs (nixpkgs-free) via mkGo. CGO_ENABLED=0,
# so the output is a fully static binary (no glibc, no patchelf). Modules are
# vendored by a single vendorHash FOD. Requires a go >= 1.26.4 toolchain (mkGo
# ships 1.26.x).
{
  mkGo,
  coreFetchurl,
  flake,
}:
mkGo {
  pname = "entire";
  version = "0.10.0";
  src = coreFetchurl {
    url = "https://github.com/entireio/cli/archive/refs/tags/v0.10.0.tar.gz";
    hash = "sha256-GlV8JDkueBna4WhNyUMhH/WsZpoC0zquZdc3OKFm4Es=";
  };
  vendorHash = "sha256-7/SWL5axi1jJur0mGEO9dMnGO8NXT1RlUnSzz/IvE0g=";
  subPackages = [ "cmd/entire" ];
  binaries = [ "entire" ];
  ldflags = [
    "-s"
    "-w"
    "-X=github.com/entireio/cli/cmd/entire/cli/versioninfo.Version=0.10.0"
  ];

  category = "Usage Analytics";
  meta = {
    description = "CLI tool that captures AI agent sessions and links them to code changes";
    homepage = "https://github.com/entireio/cli";
    changelog = "https://github.com/entireio/cli/releases/tag/v0.10.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.yutakobayashidev ];
  };
}
