# shuck: a fast shell linter + formatter (+ LSP) written in Rust - a clean-room
# alternative to shellcheck (Haskell) + shfmt (Go). Packaged here to trial it as
# the treefmt shell tool. Built with nixpkgs rustPlatform for the spike; a
# corepkgs mkCargo port can follow if we keep it.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "shuck";
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "ewhauser";
    repo = "shuck";
    tag = "v0.1.1";
    hash = "sha256-c3VW1Y59BLQjttUEtxsV6Akaa3v4haXO5285ts8VZW8=";
  };

  cargoHash = "sha256-Nu9cMXJ1xCadVglWOFZ+PT2fo9oZiKVzpCj5T0xNwts=";

  # build just the CLI crate (skip shuck-benchmark / fuzz members)
  cargoBuildFlags = [
    "-p"
    "shuck-cli"
  ];
  doCheck = false; # tests want real shells / fixtures; not needed to trial it

  passthru.hideFromDocs = true;

  meta = {
    description = "Fast shell script linter and formatter written in Rust";
    homepage = "https://github.com/ewhauser/shuck";
    license = lib.licenses.mit;
    mainProgram = "shuck";
    platforms = lib.platforms.unix;
  };
}
