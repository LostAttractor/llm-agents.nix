# crit - built from source on corepkgs (nixpkgs-free) via mkGo. CGO_ENABLED=0,
# so the output is a fully static binary (no glibc, no patchelf). Modules are
# vendored by a single vendorHash FOD. Requires a go >= 1.26 toolchain (mkGo
# ships 1.26.x).
{
  mkGo,
  coreFetchurl,
  flake,
}:
mkGo {
  pname = "crit";
  version = "0.18.4";
  src = coreFetchurl {
    url = "https://github.com/tomasz-tomczyk/crit/archive/refs/tags/v0.18.4.tar.gz";
    hash = "sha256-fknjX4ZGtpO+KfeZjTdwwD5M35d0ajbKge1xirCtZa8=";
  };
  vendorHash = "sha256-xgNFYuYw6if40UmxoAGNve9FWy6Gt5MCEIz+7CIqjRo=";
  subPackages = [ "cmd/crit" ];
  binaries = [ "crit" ];
  ldflags = [
    "-s"
    "-w"
    "-X=main.version=0.18.4"
  ];

  category = "Code Review";
  meta = {
    description = "Local-first review tool for coding-agent plans, diffs, and web pages";
    homepage = "https://github.com/tomasz-tomczyk/crit";
    changelog = "https://github.com/tomasz-tomczyk/crit/releases/tag/v0.18.4";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.ahacop ];
  };
}
