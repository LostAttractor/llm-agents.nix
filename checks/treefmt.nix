# Run treefmt over the tree and fail on any diff, so formatting drift and
# ast-grep rule violations are caught in CI instead of on the next
# contributor's `nix fmt`.
{
  pkgs,
  flake,
  system,
}:
pkgs.runCommand "treefmt-check"
  {
    nativeBuildInputs = [ flake.packages.${system}.formatter ];
  }
  ''
    cp -r ${flake} source
    chmod -R +w source
    cd source
    HOME=$TMPDIR treefmt --no-cache --fail-on-change
    touch $out
  ''
