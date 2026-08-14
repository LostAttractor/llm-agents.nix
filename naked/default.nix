# Naked build layer: packages with no nixpkgs, no stdenv. Build with:
#   nix build -f naked <attr>   (e.g. .#hello, .#seed.busybox)
let
  seed = import ./seed.nix;
  mkNaked = import ./mk-naked.nix;
in
{
  inherit seed;

  bun = import ./toolchains/bun.nix;
  node = import ./toolchains/node.nix;

  # Smoke test: prove the seed userland (busybox coreutils under bash) works.
  hello = mkNaked {
    name = "naked-hello";
    script = ''
      mkdir -p "$out/bin"
      echo '#!/bin/sh' > "$out/bin/hello"
      echo 'echo hello from a nixpkgs-free derivation' >> "$out/bin/hello"
      chmod +x "$out/bin/hello"
      # exercise a few coreutils to prove the applet bootstrap
      cp "$out/bin/hello" "$out/bin/hi"
      ln -s hello "$out/bin/hello-link"
      echo "built by: $(busybox --help 2>&1 | head -1)" > "$out/info.txt"
      ls -la "$out/bin" >> "$out/info.txt"
    '';
  };
}
