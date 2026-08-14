# Naked build layer: packages with no nixpkgs, no stdenv. Build with:
#   nix build -f naked <attr>   (e.g. .#hello, .#seed.busybox)
let
  seed = import ./seed.nix;
  mkNaked = import ./mk-naked.nix;
  checkFhs = import ./check-fhs.nix;

  eca = import ./packages/eca.nix;
  droid = import ./packages/droid.nix;
in
{
  inherit seed eca droid;

  bun = import ./toolchains/bun.nix;
  node = import ./toolchains/node.nix;
  rust = import ./toolchains/rust.nix;
  zig = import ./toolchains/zig.nix;

  # FHS-purity checks: every ELF in the output must be store-only (no leftover
  # /lib64 or /usr refs, all NEEDED libs resolve). Build all: `nix build -f naked checks.eca checks.droid`.
  checks = {
    eca = checkFhs {
      package = eca;
      name = "eca";
    };
    droid = checkFhs {
      package = droid;
      name = "droid";
    };
  };

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
