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
      rustc = "sha256-si1l/XX1DMA2wMtRRQBiglOqqBW/LhjsZWIKy4oa0kQ=";
      cargo = "sha256-3A9wxuaBd20MXgGVO1BIjosvly7tWuzm0JTkl+pICrA=";
      std = "sha256-gdfa1Yra+KmQR3HRqh6n6NxzIjb+ChsUigaM61At5/s=";
      muslStd = "sha256-nov5lIKMxF6qItlOxnTzuscQ73dxumdCvzeucGocr3U=";
    };
  };

  aarch64-linux = {
    loader = "ld-linux-aarch64.so.1";
    busybox = {
      # busybox.net ships no 64-bit aarch64 static build; use a pinned static one.
      url = "https://raw.githubusercontent.com/shutingrz/busybox-static-binaries-fat/1c31914c2398b04764b0e532299f8c842b4c6890/busybox-aarch64-linux-gnu";
      hash = "sha256-0lKJdLzmzYExtBDfj6o8vIMnqUsCgw/BbDxoZEJPlXQ=";
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
      rustc = "sha256-ZI+o0DseniaJ/FMN1WTiP122naa4LVUezMTAp/FtKL8=";
      cargo = "sha256-M1J4KLw4AmcC2FmWoowIqJTVN2pXVt2QhSR9NqoghAU=";
      std = "sha256-YJ3ys2QAnYbDti98nSIloxg507/YHALkrlYzskMs700=";
      muslStd = "sha256-71Rt+k50nFfT3UJFcxkzb2t4sJr0FENgK4myYxTEgqg=";
    };
  };
}
