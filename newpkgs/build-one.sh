#!/usr/bin/env bash
# Build + smoke-run + FHS-check ONE naked package file in isolation (imports the
# file directly, not through build.nix, so a broken sibling can't interfere).
# Usage: bash naked/build-one.sh <name>
set -u
N="$1"
R=/home/zimbatm/llm-agents.nix/newpkgs
PINS="import $R/pins-store.nix \"x86_64-linux\""
PKG="import $R/packages/$N.nix { system = \"x86_64-linux\"; pins = $PINS; }"

echo "== build $N =="
if ! out=$(nix build --no-link --print-out-paths --impure --expr "$PKG" 2>"/tmp/bo-$N.log"); then
  echo "BUILD FAILED"
  grep -vE 'untrusted|public-keys' "/tmp/bo-$N.log" | tail -20
  exit 1
fi
echo "built: $out"

echo "== smoke run =="
main=$(find "$out/bin" -maxdepth 1 -type f -o -type l | head -1)
HOME="/tmp/nh-$N" timeout 30 "$main" --version 2>&1 | head -2 ||
  HOME="/tmp/nh-$N" timeout 30 "$main" --help 2>&1 | head -2 ||
  echo "(no --version/--help; built OK)"

echo "== FHS check =="
if nix build --no-link --impure --expr "import $R/check-fhs.nix { package = $PKG; name = \"$N\"; system = \"x86_64-linux\"; pins = $PINS; }" >"/tmp/fhs-$N.log" 2>&1; then
  echo "FHS OK -- $N DONE"
else
  echo "FHS FAILED"
  grep -iE 'FHS|unresolved|NEEDED' "/tmp/fhs-$N.log" | tail -8
  exit 2
fi
