# vix - built from source on corepkgs (nixpkgs-free) via mkGo. cgo = true: the
# tree-sitter go bindings compile bundled grammar C via zig cc (no external C
# lib); the output is dynamic, patchelf'd to the pinned glibc. In-tree vendor/.
{
  mkGo,
  coreFetchurl,
  flake,
}:
mkGo {
  pname = "vix";
  version = "0.5.7";
  src = coreFetchurl {
    url = "https://github.com/get-vix/vix/archive/refs/tags/v0.5.7.tar.gz";
    hash = "sha256-/yE7Xt7DLpylDU3ZuZizjCySxxMq4g1z1TfhaYB61GQ=";
  };
  cgo = true;
  subPackages = [
    "cmd/vix"
    "cmd/vixd"
  ];
  binaries = [
    "vix"
    "vixd"
  ];
  ldflags = [
    "-s"
    "-w"
    "-X main.Version=0.5.7"
  ];
  category = "AI Coding Agents";
  meta = {
    description = "Sleek, Fast and Token Efficient AI Coding Agent";
    homepage = "https://github.com/get-vix/vix";
    changelog = "https://github.com/get-vix/vix/releases/tag/v0.5.7";
    license = flake.lib.licenses.agpl3Only;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.daspk04 ];
  };
}
