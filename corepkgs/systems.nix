# Per-system table for the naked layer (PURE - no storePath, so it is usable
# from a flake). Adding a system = adding a row. Arch-specific *pins* (glibc,
# formatelf, ...) are NOT here; they come from a pins provider threaded in
# (pins-store.nix for fast standalone eval, pins-pkgs.nix for the flake).
#
# Toolchain *versions* stay in the toolchain files (shared across arches); only
# the per-arch platform token + hash live here.
{
  x86_64-linux = {
    loader = "ld-linux-x86-64.so.2";
    busybox = {
      url = "https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox";
      hash = "sha256-mVOoYPn3r9NYiZjQf5AF2p7hXy1Q4kN5RSscc/PGpiY=";
    };
    nu = {
      url = "https://github.com/nushell/nushell/releases/download/0.114.1/nu-0.114.1-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-zjocWgfHhAmLVnUiShZec6RfD3IKg5J5HXw6W0cgJV4=";
      dir = "nu-0.114.1-x86_64-unknown-linux-musl";
    };
    bun.platform = "linux-x64";
    bun.hash = "sha256-lR7iruhV8IWVruxiJSJqKY0/6oOj3NZGXAnLzN9+hI8=";
    node.platform = "linux-x64";
    node.hash = "sha256-nZQpMlNZiAkQNNyUzF9CttyHhNY2bfOjbEycyzmW8MI=";
    zig.platform = "x86_64-linux";
    zig.hash = "sha256-cOSWZKdDdLSLUebz/fv0N/Y5XUJQkFBYi9SavlK6PQA=";
    rust = {
      gnu = "x86_64-unknown-linux-gnu";
      musl = "x86_64-unknown-linux-musl";
      rustc = "sha256-HEQeQwwcyknf9UqNWcQQOL9vefe4dWWWyy82URoBXro=";
      cargo = "sha256-kMvrit/oyg/L4BoYvZuZ0+Xpj9KcADAygo6/P/ug5O0=";
      std = "sha256-Rbkn7Pd2uWRcou1bKH/GgUgkoHPDDHxdXArUQlKV7O4=";
      muslStd = "sha256-0WDfyB0h/cclNIWfriSf7ParcGQDdfZPxOdwBaSMGNA=";
    };
  };

  # Darwin: Mach-O, not ELF - no loader, no busybox (macOS ships no static one),
  # no glibc/formatelf pins. Prebuilt CLIs link the always-present system
  # /usr/lib/libSystem via dyld, so they just run. The build leans on the system
  # toolchain in the sandbox (/usr/bin/tar, /bin/chmod) the same way nixpkgs'
  # darwin stdenv leans on system libSystem/SDK. Only nushell is fetched.
  aarch64-darwin = {
    nu = {
      url = "https://github.com/nushell/nushell/releases/download/0.114.1/nu-0.114.1-aarch64-apple-darwin.tar.gz";
      hash = "sha256-ywrJuXuYXNIXqVL0RDihTS3yqVUE2b2LwB7HPhNRsXk=";
      dir = "nu-0.114.1-aarch64-apple-darwin";
    };
  };

  x86_64-darwin = {
    nu = {
      url = "https://github.com/nushell/nushell/releases/download/0.114.1/nu-0.114.1-x86_64-apple-darwin.tar.gz";
      hash = "sha256-RlmnhUW39qMD5mH+O9J2p2XGTM3mcRLTIEW+X+B18gY=";
      dir = "nu-0.114.1-x86_64-apple-darwin";
    };
  };

  aarch64-linux = {
    loader = "ld-linux-aarch64.so.1";
    busybox = {
      # busybox.net ships no 64-bit aarch64 static build; use a pinned static one.
      url = "https://raw.githubusercontent.com/shutingrz/busybox-static-binaries-fat/1c31914c2398b04764b0e532299f8c842b4c6890/busybox-aarch64-linux-gnu";
      hash = "sha256-0lKJdLzmzYExtBDfj6o8vIMnqUsCgw/BbDxoZEJPlXQ=";
    };
    nu = {
      url = "https://github.com/nushell/nushell/releases/download/0.114.1/nu-0.114.1-aarch64-unknown-linux-musl.tar.gz";
      hash = "sha256-T56IDnu/juWPOGDvSfRT6yYolltvLIgPsD1HdfKQtTY=";
      dir = "nu-0.114.1-aarch64-unknown-linux-musl";
    };
    bun.platform = "linux-aarch64";
    bun.hash = "sha256-on/7Y6gxA3WDbg1vZorhf6jY0YuIw3yCHGUzGXOhmjs=";
    node.platform = "linux-arm64";
    node.hash = "sha256-jPMP9yUPlGO1PBj4nGxgbf2nA3ghWyyQXQqaiwi9ReA=";
    zig.platform = "aarch64-linux";
    zig.hash = "sha256-6ksJv7IuxvbGzqxXq2PvtrRuF6sI0h9p86SLOOFTTxc=";
    rust = {
      gnu = "aarch64-unknown-linux-gnu";
      musl = "aarch64-unknown-linux-musl";
      rustc = "sha256-jZ8wlaMQjjgjLxI2ReKgNovKZ8l1+LkQiABPj/2abTk=";
      cargo = "sha256-yv3iQ1GLAW+CXROl8spP/X2A9ZZt++w1Oc0JLHxPmHE=";
      std = "sha256-zv+kKP5XNQdBiFjVmt00KzUXMHJfNvdnmyUei2gQPew=";
      muslStd = "sha256-mWWX9m7CLNBAHh8XFUXNhyZ9LvtVGdgRm3R0ZwU/Q4w=";
    };
  };
}
