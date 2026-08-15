# gastown - built from source on corepkgs (nixpkgs-free) via mkGo with cgo (it
# links ICU via cgo). zig cc compiles the cgo C; the dynamic output is patchelf'd
# to the pinned glibc + icu. buildInputs pass icu (lib for rpath) + icuDev
# (pkgconfig/headers for the #cgo pkg-config).
{
  mkGo,
  coreFetchurl,
  corePins,
  flake,
}:
mkGo {
  pname = "gastown";
  version = "1.2.1";
  src = coreFetchurl {
    url = "https://github.com/gastownhall/gastown/archive/refs/tags/v1.2.1.tar.gz";
    hash = "sha256-9cXvzcHsxA8rjvuVpYJviLphlhN7wukZ1go5tCz0Rro=";
  };
  vendorHash = "sha256-PQT/Xq9na3vI8Oy9INBYJf3GsiN5IxAVCxrNLhyIpO8=";
  cgo = true;
  buildInputs = [
    corePins.icu
    corePins.icuDev
  ];
  subPackages = [ "cmd/gt" ];
  binaries = [ "gt" ];
  ldflags = [
    "-s"
    "-w"
    "-X=github.com/steveyegge/gastown/internal/cmd.Version=1.2.1"
    "-X=github.com/steveyegge/gastown/internal/cmd.Build=release"
    "-X=github.com/steveyegge/gastown/internal/cmd.BuiltProperly=1"
  ];
  category = "Workflow & Project Management";
  meta = {
    description = "Gas Town - multi-agent workspace manager";
    homepage = "https://github.com/gastownhall/gastown";
    changelog = "https://github.com/gastownhall/gastown/releases/tag/v1.2.1";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.zaninime ];
  };
}
