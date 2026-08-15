# beads - built from source on corepkgs (nixpkgs-free) via mkGo with cgo. It
# links ICU via go-icu-regex's cgo. zig cc compiles the cgo C; the dynamic
# output is patchelf'd to the pinned glibc + icu. buildInputs pass icu (lib for
# rpath) + icuDev (pkgconfig/headers). Note: upstream wraps bd with dolt on
# PATH; mkGo does not wrap, so dolt must be provided at runtime separately.
{
  mkGo,
  coreFetchurl,
  corePins,
  flake,
}:
mkGo {
  pname = "beads";
  version = "1.2.1";
  src = coreFetchurl {
    url = "https://github.com/gastownhall/beads/archive/refs/tags/v1.2.1.tar.gz";
    hash = "sha256-s4VS0aMQ2T9LeyPxW/HQzv1T5WXX9DzMkPiVYRGQXPc=";
  };
  vendorHash = "sha256-mflgEu9g1k0UeyMA30WT4ON/8bpsNyIbIjAVTbjXpCs=";
  cgo = true;
  buildInputs = [
    corePins.icu
    corePins.icuDev
  ];
  subPackages = [ "cmd/bd" ];
  binaries = [ "bd" ];
  category = "Workflow & Project Management";
  meta = {
    description = "A distributed issue tracker designed for AI-supervised coding workflows";
    homepage = "https://github.com/gastownhall/beads";
    changelog = "https://github.com/gastownhall/beads/releases/tag/v1.2.1";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.zimbatm ];
  };
}
