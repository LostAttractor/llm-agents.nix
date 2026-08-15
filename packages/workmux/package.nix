# workmux - built from source on corepkgs (nixpkgs-free) via mkCargo. Pure
# crates.io except one git dependency (an upstream crossterm fork), vendored via
# gitDeps (the github archive at the locked rev, wired as a cargo source
# replacement). No C libraries.
{
  mkCargo,
  coreFetchurl,
  flake,
}:
mkCargo {
  pname = "workmux";
  version = "0.1.238";
  src = coreFetchurl {
    url = "https://github.com/raine/workmux/archive/refs/tags/v0.1.238.tar.gz";
    hash = "sha256-NIIz2qgc1VLPsEFr13ZBNOAcIomwF17InZG+9YRfEY0=";
  };
  cargoLock = ./Cargo.lock;
  binaries = [ "workmux" ];
  gitDeps = [
    {
      crate = "crossterm";
      source = "git+https://github.com/raine/crossterm#f99eeae405e28fa8cb353a6c6e36c493e72891bd";
      hash = "sha256-2hn4NpzVU8ASCRDgdbpOmVVVGQLxEewvU4Vp4aVUGHU=";
    }
  ];

  category = "Workflow & Project Management";
  meta = {
    description = "Git worktrees + tmux windows for zero-friction parallel dev";
    homepage = "https://github.com/raine/workmux";
    changelog = "https://github.com/raine/workmux/blob/v0.1.238/CHANGELOG.md";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ ];
  };
}
