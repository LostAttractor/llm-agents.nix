let
  mkNaked = import ./mk-naked.nix;
  rust = import ./toolchains/rust.nix;
in
mkNaked {
  name = "rustc-compile-demo";
  env = { inherit rust; };
  script = ''
    mkdir -p "$out"
    cat > hello.rs <<'RS'
    pub fn add(a: i32, b: i32) -> i32 { a + b }
    pub fn greeting() -> String { format!("compiled by naked rustc: {}", add(2, 2)) }
    RS
    # --crate-type rlib exercises the frontend + LLVM codegen + std resolution
    # without invoking an external C linker.
    "$rust/bin/rustc" --crate-type rlib --edition 2021 -O hello.rs -o "$out/libhello.rlib"
    "$rust/bin/rustc" --crate-type rlib --edition 2021 --emit=metadata hello.rs -o "$out/hello.rmeta"
    ls -la "$out" > "$out/result.txt"
    echo "rustc produced an rlib from source with no nixpkgs and no cc" >> "$out/result.txt"
  '';
}
