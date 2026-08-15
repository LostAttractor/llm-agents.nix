# beads-rust (br) - built from source on corepkgs (nixpkgs-free) via mkCargo.
# Pure crates.io deps (the published fsqlite-* crates resolve from crates.io with
# checksums). fsqlite uses #![feature(...)] gated to nightly, so RUSTC_BOOTSTRAP=1
# enables those on the stable toolchain (same as the nixpkgs recipe).
{
  mkCargo,
  coreFetchurl,
  flake,
}:
mkCargo {
  pname = "beads-rust";
  version = "0.3.0";
  src = coreFetchurl {
    url = "https://github.com/Dicklesworthstone/beads_rust/archive/refs/tags/v0.3.0.tar.gz";
    hash = "sha256-SGovt/EiAiQRVc+c95crnG8Gtzz+KO28aLezltGzV3M=";
  };
  cargoLock = ./Cargo.lock;
  binaries = [ "br" ];
  mainProgram = "br";
  # self_update feature makes no sense under Nix; drop it (nixpkgs does the same).
  cargoBuildFlags = [ "--no-default-features" ];
  extraEnv.RUSTC_BOOTSTRAP = "1";

  category = "Workflow & Project Management";
  meta = {
    description = "Fast Rust port of beads - a local-first issue tracker for git repositories";
    homepage = "https://github.com/Dicklesworthstone/beads_rust";
    changelog = "https://github.com/Dicklesworthstone/beads_rust/releases/tag/v0.3.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.afterthought ];
  };
}
