# cc-switch-cli - built from source on corepkgs (nixpkgs-free) via mkCargo. The
# crate lives in the `src-tauri` subdir but is a plain CLI (no tauri frontend);
# it installs the `cc-switch` binary. Several deps bundle their own C and compile
# it through the `cc` crate (rusqlite "bundled", rquickjs' quickjs, ring via
# rustls, brotli), which uses our `zig cc` wrapper - no external C libs.
{
  mkCargo,
  coreFetchurl,
  flake,
}:
mkCargo {
  pname = "cc-switch-cli";
  version = "5.10.1";
  src = coreFetchurl {
    url = "https://github.com/SaladDay/cc-switch-cli/archive/refs/tags/v5.10.1.tar.gz";
    hash = "sha256-jgMgK7RSVaUvdBMr1zEPfbRL25g/y3c3ZC1Ar1h3drI=";
  };
  cargoLock = ./Cargo.lock;
  sourceRoot = "src-tauri";
  binaries = [ "cc-switch" ];
  # Manifest gates on rustc 1.91.1; our pinned toolchain is 1.90.0. The code
  # itself compiles on 1.90, so skip the rust-version check.
  cargoBuildFlags = [ "--ignore-rust-version" ];

  category = "Claude Code Ecosystem";
  meta = {
    description = "CLI version of CC Switch - All-in-One Assistant for Claude Code, Codex & Gemini CLI";
    homepage = "https://github.com/SaladDay/cc-switch-cli";
    changelog = "https://github.com/SaladDay/cc-switch-cli/releases/tag/v5.10.1";
    downloadPage = "https://github.com/SaladDay/cc-switch-cli/releases";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.zrubing ];
    mainProgram = "cc-switch";
  };
}
