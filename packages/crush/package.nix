# crush - built from source on corepkgs (nixpkgs-free) via mkGo. CGO_ENABLED=0,
# so the output is a fully static binary (no glibc, no patchelf). Modules are
# vendored by a single vendorHash FOD (go.sum hashes are not fetchurl-compatible).
{
  mkGo,
  coreFetchurl,
  flake,
}:
mkGo {
  pname = "crush";
  version = "0.89.0";
  src = coreFetchurl {
    url = "https://github.com/charmbracelet/crush/archive/refs/tags/v0.89.0.tar.gz";
    hash = "sha256-sKLpq9SNcNJtvPwaqLgQ3hBJkem/qAJSlowvpPxkY6U=";
  };
  vendorHash = "sha256-zY45d6TIUNmL8qriE8LQkxdOSHTEKDasbzNHeHyEbiI=";
  binaries = [ "crush" ];
  ldflags = [
    "-s"
    "-w"
    "-X=github.com/charmbracelet/crush/internal/version.Version=0.89.0"
  ];

  category = "AI Coding Agents";
  meta = {
    description = "Glamourous AI coding agent for your favourite terminal";
    homepage = "https://github.com/charmbracelet/crush";
    changelog = "https://github.com/charmbracelet/crush/releases/tag/v0.89.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.zimbatm ];
  };
}
