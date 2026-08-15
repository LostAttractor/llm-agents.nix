# tuicr - built from source on corepkgs (nixpkgs-free) via mkCargo. Uses git2,
# whose libgit2-sys bundles and compiles its own libgit2 C through the `cc` crate
# (our `zig cc` wrapper as $CC) when no system libgit2 is found - so no external
# C libraries. Pure crates.io, no git deps.
{
  mkCargo,
  coreFetchurl,
  flake,
}:
mkCargo {
  pname = "tuicr";
  version = "0.22.0";
  src = coreFetchurl {
    url = "https://github.com/agavra/tuicr/archive/refs/tags/v0.22.0.tar.gz";
    hash = "sha256-Ze5kn0bUKtCq+5TrYY/bmNZVXpeUlc/0WjTzdTF0fFI=";
  };
  cargoLock = ./Cargo.lock;
  binaries = [ "tuicr" ];

  category = "Code Review";
  meta = {
    description = "Review AI-generated diffs like a GitHub pull request, right from your terminal";
    homepage = "https://github.com/agavra/tuicr";
    changelog = "https://github.com/agavra/tuicr/releases/tag/v0.22.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.ypares ];
  };
}
