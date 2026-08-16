# Pin provider that is BOTH pure AND nixpkgs-free: the exact same store paths as
# pins-store.nix, but fetched with `builtins.fetchClosure` from a binary cache
# instead of referenced via impure `builtins.storePath`. This lets corepkgs be a
# standalone flake with ZERO nixpkgs input - eval touches no nixpkgs, yet stays
# pure (fetchClosure of an input-addressed path is deterministic + signature
# checked), so it works as a flake output.
#
# The nixpkgs pins live on cache.nixos.org (they are stock nixpkgs outputs);
# formatelf (this repo's patchelf replacement) is on cache.numtide.com.
# Regenerate the paths on a nixpkgs / formatelf bump (same paths as pins-store).
#
# Further step (see [[corepkgs-bootstrap-direction]]): replace the cache.nixos.org
# dependency with our own from-source bootstrap tarballs on a github release, so
# corepkgs depends on nothing but upstream release artifacts.
system:
let
  nixos =
    path:
    builtins.fetchClosure {
      fromStore = "https://cache.nixos.org";
      fromPath = path;
      inputAddressed = true;
    };
  numtide =
    path:
    builtins.fetchClosure {
      fromStore = "https://cache.numtide.com";
      fromPath = path;
      inputAddressed = true;
    };
in
{
  x86_64-linux = {
    glibc = nixos /nix/store/0d8g8n0a11v6f5m2h416ajyxmnkwc3md-glibc-2.42-67;
    gccLib = nixos /nix/store/r48746qznwqxxl9qzd8f08ny8mg1dg2y-gcc-15.3.0-lib;
    zlib = nixos /nix/store/zks9mfsn4rqr6z9g6pcj2xqzcsplj0nb-zlib-1.3.2;
    zstd = nixos /nix/store/pxahscw9vl9vac1nbjpy6bhz3vbk3cpl-zstd-1.5.7;
    formatelf = numtide /nix/store/r6a970q9v1bzdfrd8dcqjmnfs94lh45g-formatelf-0-unstable-2026-08-11;
    # runtime deps for the ported packages (x86_64-only, so aarch64 omits them)
    ripgrep = nixos /nix/store/axp6zlky4x2v3jwcbq24a2cz25hzlw9b-ripgrep-15.2.0;
    coreutils = nixos /nix/store/97d5ygrvqj55f4nx1x34wfdcc7qn11c0-coreutils-9.11;
    # manylinux external libs for python wheels (glibc/gccLib/zlib already above)
    libffi = nixos /nix/store/wflv43s0i42ysmjvw1hiw4vdiidfzwnn-libffi-3.7.1;
    expat = nixos /nix/store/x7hyp2ndwysydy2q1djdvjzlqzvqhg8x-expat-2.8.2;
    ncurses = nixos /nix/store/zlvs6miv8wfki399pmxri7x0sjd3429c-ncurses-6.6;
    openssl = nixos /nix/store/1mf3lj0mldr8732yvzjc12fig2407b3d-openssl-3.6.3;
    opensslDev = nixos /nix/store/jvnhc1z9c04n4a7b2z2hzbajsa5i6ygd-openssl-3.6.3-dev;
    pkgConfig = nixos /nix/store/0v0raqk1qw5g2a21km4xa1hwhaq4s976-pkg-config-wrapper-0.29.2;
    icu = nixos /nix/store/nv8jd3fvfv8p1d6dxflk1snfxzwabbm7-icu4c-78.3;
    icuDev = nixos /nix/store/ahpzhy9kw4w3wnva40n8bi6qlhn9frsy-icu4c-78.3-dev;
    bzip2 = nixos /nix/store/0hckf4kx70qifvrsbh64hc2s5xfyrf97-bzip2-1.0.8;
    xz = nixos /nix/store/96hgnqnikm0k4pag8x35hb6s46nag1l3-xz-5.8.3;
    bubblewrap = nixos /nix/store/lqndphylsxqwbwm804n473pb4sqb98sh-bubblewrap-0.11.2;
    socat = nixos /nix/store/b6jsx5bi7n3hhfmdlhczl60ssvyphj3g-socat-1.8.1.3;
  };
  aarch64-linux = {
    glibc = nixos /nix/store/f8q4w2hbjvwy7qqwpnvbf5f4qwyww6cp-glibc-2.42-67;
    gccLib = nixos /nix/store/ylzalvsf8nxhidm1p72k6ckxckpj1wd3-gcc-15.3.0-lib;
    zlib = nixos /nix/store/3v2w5hdrpzwx3w8svda35lyrq9jwqbc8-zlib-1.3.2;
    zstd = nixos /nix/store/k2fr8pihnym47m71fij3ns184vbx4v79-zstd-1.5.7;
    formatelf = numtide /nix/store/hk6nkaqbxlyymm91gw9v3rr5b88z0mqy-formatelf-0-unstable-2026-08-11;
  };
}
.${system}
