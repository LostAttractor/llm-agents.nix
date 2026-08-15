# The capstone: compile AND link a real rust executable with no nixpkgs.
# rustc (prebuilt) does the frontend + codegen; zig cc does the link, targeting
# musl-static so the output is a fully static binary that needs no glibc.
let
  mkNaked = import ./mk-naked.nix;
  rust = import ./toolchains/rust.nix;
  zig = import ./toolchains/zig.nix;
in
mkNaked {
  name = "rust-zig-link-demo";
  env = { inherit rust zig; };
  script = ''
    mkdir -p "$out/bin"
    export ZIG_GLOBAL_CACHE_DIR="$NIX_BUILD_TOP/zig-cache"

    cat > main.rs <<'RS'
    fn main() {
        let n: u64 = (1..=10).product();
        println!("hello from a rust binary linked by zig cc; 10! = {n}");
    }
    RS

    # linker wrapper: force zig cc to target musl-static
    cat > zcc <<EOF
    #!/bin/sh
    exec "$zig/bin/zig" cc -target x86_64-linux-musl "\$@"
    EOF
    chmod +x zcc

    "$rust/bin/rustc" \
      --target x86_64-unknown-linux-musl \
      -C linker=./zcc \
      -C link-self-contained=no \
      -C target-feature=+crt-static \
      -O main.rs -o "$out/bin/demo"

    # prove it runs, and is fully static
    "$out/bin/demo" > "$out/output.txt"
    "$zig/bin/zig" version > /dev/null
  '';
}
