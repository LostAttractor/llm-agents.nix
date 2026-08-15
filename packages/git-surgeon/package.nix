# git-surgeon - built from source on corepkgs (nixpkgs-free): mkCargo drives the
# naked rust toolchain + zig cc + cargo-vendor'd crates. Pure crates.io deps, no
# C libraries, so it ports cleanly. The Cargo.lock is vendored alongside (the
# nixpkgs-free equivalent of a cargoHash).
{
  mkCargo,
  coreFetchurl,
  flake,
}:
mkCargo {
  pname = "git-surgeon";
  version = "0.1.17";
  src = coreFetchurl {
    url = "https://github.com/raine/git-surgeon/archive/refs/tags/v0.1.17.tar.gz";
    hash = "sha256-xnQm0BEXgLfxPUVVQZLaYlOzu2dpYUSdYBEK8X6D+Oo=";
  };
  cargoLock = ./Cargo.lock;
  binaries = [ "git-surgeon" ];

  category = "Utilities";
  meta = {
    description = "Git primitives for autonomous coding agents";
    homepage = "https://github.com/raine/git-surgeon";
    changelog = "https://github.com/raine/git-surgeon/blob/v0.1.17/CHANGELOG.md";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.sei40kr ];
  };
}
