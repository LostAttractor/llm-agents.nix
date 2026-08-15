# toon - built from source on corepkgs (nixpkgs-free) via mkCargo. Pure crates.io
# deps, no C libraries; the "cli" feature pulls the toon binary. Source is the
# published crate tarball from crates.io (not a GitHub archive).
{
  mkCargo,
  coreFetchurl,
  flake,
}:
mkCargo {
  pname = "toon-format";
  version = "0.5.0";
  src = coreFetchurl {
    url = "https://static.crates.io/crates/toon-format/toon-format-0.5.0.crate";
    hash = "sha256-j4lXDBpo1zlB9yjMoypDRbL/yjZmetkhrzNsYDCaPn4=";
  };
  cargoLock = ./Cargo.lock;
  binaries = [ "toon" ];
  cargoBuildFlags = [
    "--features"
    "cli"
  ];

  category = "Utilities";
  meta = {
    description = "Rust implementation of TOON - Token-Oriented Object Notation for LLM prompts";
    homepage = "https://github.com/toon-format/toon-rust";
    changelog = "https://github.com/toon-format/toon-rust/releases/tag/v0.5.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.antono ];
  };
}
