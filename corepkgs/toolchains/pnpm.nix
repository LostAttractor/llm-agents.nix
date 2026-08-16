# pnpm toolchain: the pnpm npm package (a self-contained JS bundle) run on the
# naked node toolchain - no separate binary to patchelf. `pnpm` is a wrapper that
# execs `node dist/pnpm.cjs`, so it inherits node's pinned-glibc runtime.
{
  system,
  node,
}:
let
  fetchurl = import ../fetch/fetchurl.nix;
  mkNaked = import ../mk/naked-sh.nix;
  version = "10.18.2";
  tgz = fetchurl {
    url = "https://registry.npmjs.org/pnpm/-/pnpm-${version}.tgz";
    hash = "sha256-k0IQIv4BVtfL32me3D1+qzllSYbqwU+SfQK4Xw2sbWE=";
    name = "pnpm-${version}.tgz";
  };
in
mkNaked {
  inherit system;
  name = "pnpm-${version}";
  env = { inherit tgz node; };
  script = ''
    mkdir -p "$out/libexec/pnpm" "$out/bin"
    tar -xzf "$tgz" -C "$out/libexec/pnpm" --strip-components=1
    {
      echo "#!/bin/sh"
      echo "exec \"$node/bin/node\" \"$out/libexec/pnpm/dist/pnpm.cjs\" \"\$@\""
    } > "$out/bin/pnpm"
    chmod +x "$out/bin/pnpm"
    "$out/bin/pnpm" --version > "$out/version.txt"
  '';
}
