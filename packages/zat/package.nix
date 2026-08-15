# zat - built from source on corepkgs (nixpkgs-free) via mkCargo. Pure crates.io
# deps; the tree-sitter grammar crates bundle their own C and compile it through
# the `cc` crate, which uses our `zig cc` wrapper as $CC - so no external C libs.
{
  mkCargo,
  coreFetchurl,
  flake,
}:
mkCargo {
  pname = "zat";
  version = "0.5.4";
  src = coreFetchurl {
    url = "https://github.com/bglgwyng/zat/archive/refs/tags/v0.5.4.tar.gz";
    hash = "sha256-wIkckBtXMhIjzACv/CC4vC/MCObAHCDul3wsxDfCDJs=";
  };
  cargoLock = ./Cargo.lock;
  binaries = [ "zat" ];

  category = "Memory & Code Intelligence";
  meta = {
    description = "Code outline viewer for LLM coding agents — shows exported symbols with line numbers";
    homepage = "https://github.com/bglgwyng/zat";
    changelog = "https://github.com/bglgwyng/zat/releases/tag/v0.5.4";
    license = flake.lib.licenses.gpl3Only;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.mic92 ];
  };
}
