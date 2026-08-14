# Per-system table for the naked layer. Adding a system = adding a row; every
# arch-specific constant (seed binary, ELF loader, pinned tools, toolchain
# artifact hashes, rust target triples) lives here and nothing else hardcodes an
# architecture. Toolchain *versions* stay in the toolchain files (shared across
# arches); only the per-arch platform token + hash live here.
#
# pins are store paths (builtins.storePath). x86_64-linux's are always present
# (we build with them); aarch64-linux's resolve once substituted from the
# binary caches (they cannot be built on an x86_64 machine, only substituted).
{
  x86_64-linux = {
    loader = "ld-linux-x86-64.so.2";
    busybox = {
      url = "https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox";
      hash = "sha256-mVOoYPn3r9NYiZjQf5AF2p7hXy1Q4kN5RSscc/PGpiY=";
    };
    pins = {
      glibc = builtins.storePath /nix/store/0d8g8n0a11v6f5m2h416ajyxmnkwc3md-glibc-2.42-67;
      gccLib = builtins.storePath /nix/store/r48746qznwqxxl9qzd8f08ny8mg1dg2y-gcc-15.3.0-lib;
      zlib = builtins.storePath /nix/store/zks9mfsn4rqr6z9g6pcj2xqzcsplj0nb-zlib-1.3.2;
      zstd = builtins.storePath /nix/store/pxahscw9vl9vac1nbjpy6bhz3vbk3cpl-zstd-1.5.7;
      formatelf = builtins.storePath /nix/store/r6a970q9v1bzdfrd8dcqjmnfs94lh45g-formatelf-0-unstable-2026-08-11;
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
    pins = {
      glibc = builtins.storePath /nix/store/f8q4w2hbjvwy7qqwpnvbf5f4qwyww6cp-glibc-2.42-67;
      gccLib = builtins.storePath /nix/store/ylzalvsf8nxhidm1p72k6ckxckpj1wd3-gcc-15.3.0-lib;
      zlib = builtins.storePath /nix/store/3v2w5hdrpzwx3w8svda35lyrq9jwqbc8-zlib-1.3.2;
      zstd = builtins.storePath /nix/store/k2fr8pihnym47m71fij3ns184vbx4v79-zstd-1.5.7;
      formatelf = builtins.storePath /nix/store/hk6nkaqbxlyymm91gw9v3rr5b88z0mqy-formatelf-0-unstable-2026-08-11;
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
