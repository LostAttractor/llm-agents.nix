# Naked build layer: packages with no nixpkgs, no stdenv. Build with:
#   nix build -f naked <attr>              (x86_64-linux toolchains + packages)
#   nix build -f naked aarch64-linux.rust  (another system, via the table)
#
# Everything arch-specific lives in systems.nix; adding a system is adding a row
# there. NOTE: only x86_64-linux can be *built* on an x86_64 machine; the
# aarch64-linux.* attrs *evaluate* (well-formed derivations) but need an aarch64
# builder (or the pins substituted) to realise.
let
  mkNaked = import ./mk-naked.nix;
  checkFhs = import ./check-fhs.nix;

  # Toolchains + seed + smoke test for a given system (all system-parameterized).
  toolchainsFor = system: {
    seed = import ./seed.nix { inherit system; };
    bun = import ./toolchains/bun.nix { inherit system; };
    node = import ./toolchains/node.nix { inherit system; };
    rust = import ./toolchains/rust.nix { inherit system; };
    zig = import ./toolchains/zig.nix { inherit system; };
    formatelf = import ./formatelf.nix { inherit system; };
    hello = mkNaked {
      inherit system;
      name = "naked-hello";
      script = ''
        mkdir -p "$out/bin"
        echo '#!/bin/sh' > "$out/bin/hello"
        echo 'echo hello from a nixpkgs-free derivation' >> "$out/bin/hello"
        chmod +x "$out/bin/hello"
        cp "$out/bin/hello" "$out/bin/hi"
        ln -s hello "$out/bin/hello-link"
      '';
    };
  };

  # Binary-wrapper package ports (x86_64-linux only for now: each needs its own
  # per-arch release URLs + hashes to go multi-arch).
  eca = import ./packages/eca.nix;
  droid = import ./packages/droid.nix;
  grok = import ./packages/grok.nix;
  coderabbit_cli = import ./packages/coderabbit-cli.nix;
  cubic = import ./packages/cubic.nix;
  forgecode = import ./packages/forgecode.nix;
  kilocode_cli = import ./packages/kilocode-cli.nix;
  jules = import ./packages/jules.nix;
  open_code_review = import ./packages/open-code-review.nix;
in
(toolchainsFor "x86_64-linux")
// {
  # per-system toolchain sets
  x86_64-linux = toolchainsFor "x86_64-linux";
  aarch64-linux = toolchainsFor "aarch64-linux";

  # x86_64 binary-wrapper packages
  inherit
    eca
    droid
    grok
    cubic
    forgecode
    jules
    ;
  coderabbit-cli = coderabbit_cli;
  open-code-review = open_code_review;
  kilocode-cli = kilocode_cli;

  # FHS-purity checks (mechanism-aware; see check-fhs.nix)
  checks = {
    eca = checkFhs {
      system = "x86_64-linux";
      package = eca;
      name = "eca";
    };
    droid = checkFhs {
      system = "x86_64-linux";
      package = droid;
      name = "droid";
    };
    grok = checkFhs {
      system = "x86_64-linux";
      package = grok;
      name = "grok";
    };
    coderabbit-cli = checkFhs {
      system = "x86_64-linux";
      package = coderabbit_cli;
      name = "coderabbit-cli";
    };
    cubic = checkFhs {
      system = "x86_64-linux";
      package = cubic;
      name = "cubic";
    };
    forgecode = checkFhs {
      system = "x86_64-linux";
      package = forgecode;
      name = "forgecode";
    };
    open-code-review = checkFhs {
      system = "x86_64-linux";
      package = open_code_review;
      name = "open-code-review";
    };
    jules = checkFhs {
      system = "x86_64-linux";
      package = jules;
      name = "jules";
    };
    kilocode-cli = checkFhs {
      system = "x86_64-linux";
      package = kilocode_cli;
      name = "kilocode-cli";
    };
  };
}
