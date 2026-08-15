# chainlink - built from source on corepkgs (nixpkgs-free) via mkCargo. The rust
# crate lives in the chainlink/ subdir. rusqlite is used with the "bundled"
# feature, so libsqlite3-sys compiles its own C through the `cc` crate (our
# `zig cc` wrapper as $CC) - no external C libraries. The build.rs tries to
# embed a git hash; with no .git it falls back to CARGO_PKG_VERSION. The
# upstream Cargo.toml version (0.1.3) does not match release tags, so the
# reported --version reflects the crate manifest, not this package version.
{
  mkCargo,
  coreFetchurl,
  flake,
}:
mkCargo {
  pname = "chainlink";
  version = "1.6.0";
  src = coreFetchurl {
    url = "https://github.com/dollspace-gay/chainlink/archive/refs/tags/chainlink-1.6.0.tar.gz";
    hash = "sha256-4DccXgZ6MwQP1iBFcyDtVcdKz0Vbxc0Y4MGta+0688M=";
  };
  cargoLock = ./Cargo.lock;
  sourceRoot = "chainlink";
  binaries = [ "chainlink" ];

  category = "Workflow & Project Management";
  meta = {
    description = "Simple, lean issue tracker CLI designed for AI-assisted development";
    homepage = "https://github.com/dollspace-gay/chainlink";
    changelog = "https://github.com/dollspace-gay/chainlink/releases/tag/chainlink-1.6.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.Chickensoupwithrice ];
  };
}
