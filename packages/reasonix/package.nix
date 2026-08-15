# reasonix - built from source on corepkgs (nixpkgs-free) via mkGo. CGO_ENABLED=0,
# so the output is a fully static binary (no glibc, no patchelf). Modules are
# vendored by a single vendorHash FOD (go.sum hashes are not fetchurl-compatible).
{
  mkGo,
  coreFetchurl,
  flake,
}:
mkGo {
  pname = "reasonix";
  version = "1.25.2";
  src = coreFetchurl {
    url = "https://github.com/esengine/DeepSeek-Reasonix/archive/refs/tags/v1.25.2.tar.gz";
    hash = "sha256-x/3lh3b2zINYPuQf/4Qyb2Luj29tLp31LepUgYBsnyc=";
  };
  vendorHash = "sha256-uKrReMcR7L+8E4t/jY32/YW11bXROgtwl9kl4KxgQdM=";
  subPackages = [ "cmd/reasonix" ];
  binaries = [ "reasonix" ];
  ldflags = [
    "-s"
    "-w"
    "-X=main.version=v1.25.2"
  ];

  category = "AI Coding Agents";
  meta = {
    description = "DeepSeek-native AI coding agent for your terminal";
    homepage = "https://github.com/esengine/DeepSeek-Reasonix";
    changelog = "https://github.com/esengine/DeepSeek-Reasonix/releases/tag/v1.25.2";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.arch-fan ];
  };
}
