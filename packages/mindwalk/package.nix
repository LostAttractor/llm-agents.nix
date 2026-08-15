# mindwalk - built from source on corepkgs (nixpkgs-free) via mkGo. CGO_ENABLED=0,
# so the output is a fully static binary (no glibc, no patchelf). Modules are
# vendored by a single vendorHash FOD (go.sum hashes are not fetchurl-compatible).
{
  mkGo,
  coreFetchurl,
  flake,
}:
mkGo {
  pname = "mindwalk";
  version = "0.5.0";
  src = coreFetchurl {
    url = "https://github.com/cosmtrek/mindwalk/archive/refs/tags/v0.5.0.tar.gz";
    hash = "sha256-hNL6FQan4OD3lOgeT82AUFpIhGzCRy6e3oKUJYHZKoI=";
  };
  vendorHash = "sha256-qVoj03LNLbdoCUAOydK7oEHsuZ1BZ6Z2jwYB3gPOfrw=";
  subPackages = [ "cmd/mindwalk" ];
  binaries = [ "mindwalk" ];
  ldflags = [
    "-s"
    "-w"
  ];

  category = "Usage Analytics";
  meta = {
    description = "Visualization tool that replays coding-agent sessions on a 3D map of your codebase";
    homepage = "https://github.com/cosmtrek/mindwalk";
    changelog = "https://github.com/cosmtrek/mindwalk/releases/tag/v0.5.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.zimbatm ];
  };
}
