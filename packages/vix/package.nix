# vix - built from source on corepkgs (nixpkgs-free) via mkGo, static
# (CGO_ENABLED=0). No external deps (stdlib only), so no vendorHash. Two bins.
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
