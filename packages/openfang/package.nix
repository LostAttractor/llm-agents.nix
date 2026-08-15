# openfang - built from source on corepkgs (nixpkgs-free) via mkCargo. Uses
# native-tls -> openssl-sys; openssl = true wires the pinned openssl (headers +
# libs, OPENSSL_NO_VENDOR) so it links our openssl instead of building one from
# source with perl.
{
  mkCargo,
  coreFetchurl,
  flake,
}:
mkCargo {
  pname = "openfang";
  version = "0.6.9";
  src = coreFetchurl {
    url = "https://github.com/RightNow-AI/openfang/archive/refs/tags/v0.6.9.tar.gz";
    hash = "sha256-U2202hqDZPVqd5gWWhxYAaZ7cgpGBkOm2N8LTtImr1o=";
  };
  cargoLock = ./Cargo.lock;
  binaries = [ "openfang" ];
  cargoBuildFlags = [
    "--package"
    "openfang-cli"
  ];
  openssl = true;

  category = "AI Coding Agents";
  meta = {
    description = "Open-source Agent OS built in Rust — CLI for the OpenFang platform";
    homepage = "https://github.com/RightNow-AI/openfang";
    changelog = "https://github.com/RightNow-AI/openfang/releases/tag/v0.6.9";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.viniciuspalma ];
  };
}
