# mkPnpm: build a pnpm project from source, nixpkgs-free, with the node +
# pnpm toolchains. Deps are vendored by vendor/pnpm.nix (a flat hoisted
# node_modules FOD, our own pnpmDepsHash). Runs the package's build script via
# pnpm, installs dist + node_modules under $out/lib/<pname>, and wraps
# `node <entry>` as $out/bin/<mainProgram> - the shape nixpkgs uses for pnpm CLIs.
{
  pname,
  version,
  src, # fetched source archive (.tar.gz, single top-level dir)
  pnpmDepsHash, # our node_modules FOD hash (build once with a fake hash to obtain)
  entry, # script node runs, relative to the app root (e.g. "dist/cli.js")
  buildScript ? "build", # `pnpm run <buildScript>`; "" to skip (no build step)
  postPatch ? "", # shell run in the source before the build (e.g. a lockfile fixup)
  sourceRoot ? null, # subdir holding package.json (relative to the tarball top dir)
  mainProgram ? pname,
  meta ? { },
  category ? null,
  updater ? null,
  system,
  pins,
  toolchains,
}:
let
  mkDrvSh = import ./drv-sh.nix;
  inherit (toolchains) node pnpm;
  vendor = import ../vendor/pnpm.nix {
    inherit
      src
      pnpmDepsHash
      sourceRoot
      postPatch
      system
      pnpm
      node
      ;
  };
  libpath = "${pins.glibc}/lib:${pins.gccLib}/lib";
  drv = mkDrvSh {
    inherit system;
    name = "${pname}-${version}";
    env = {
      inherit
        src
        node
        pnpm
        vendor
        pname
        mainProgram
        entry
        buildScript
        postPatch
        ;
      sourceRoot = if sourceRoot == null then "" else sourceRoot;
      formatelf = pins.formatelf;
      inherit libpath;
    };
    script = ''
      export HOME="$NIX_BUILD_TOP"
      export PATH="$pnpm/bin:$node/bin:$PATH"
      # native build tools (esbuild/... via .node) need libstdc++ at build time
      export LD_LIBRARY_PATH="$libpath"

      tar -xzf "$src"
      cd "$(tar -tzf "$src" | head -1 | cut -d/ -f1)"
      [ -n "$sourceRoot" ] && cd "$sourceRoot"
      eval "$postPatch"

      # drop in the vendored node_modules (the FOD is read-only)
      cp -r "$vendor" node_modules
      chmod -R u+w node_modules

      # patchShebangs: the sandbox has no /usr/bin/env, so rewrite the
      # `#!/usr/bin/env node` in node_modules/.bin targets to our node.
      for l in node_modules/.bin/*; do
        [ -e "$l" ] || continue
        t=$(readlink -f "$l" 2>/dev/null) || continue
        [ -f "$t" ] || continue
        case "$(head -1 "$t" 2>/dev/null)" in
          "#!/usr/bin/env node"*|"#! /usr/bin/env node"*|"#!/usr/bin/node"*)
            sed -i "1s|.*|#!$node/bin/node|" "$t" ;;
        esac
      done

      # build (tsc/vite/... via the package's own script) against the vendored
      # node_modules. Via .npmrc (not env, which nested `pnpm --filter` runs drop):
      # offline (deps already present) + disable package-manager self-management
      # (pnpm 10 otherwise fetches the exact pnpm in package.json's
      # "packageManager" field, which fails offline).
      printf 'offline=true\nmanage-package-manager-versions=false\n' >> .npmrc
      [ -n "$buildScript" ] && pnpm run "$buildScript"

      # install dist + node_modules + package.json under $out/lib/<pname>
      dest="$out/lib/$pname"
      mkdir -p "$dest" "$out/bin"
      cp -r . "$dest/"

      # patchelf bundled prebuilt native addons (*.node) to the pinned glibc.
      find "$dest" -name '*.node' -type f | while read -r so; do
        [ "$(head -c4 "$so" | od -An -tx1 | tr -d ' \n')" = "7f454c46" ] || continue
        "$formatelf/bin/formatelf" --force-rpath --set-rpath "$libpath" "$so" 2>/dev/null || true
      done

      # wrapper: run the built entry on the pinned node toolchain
      {
        echo "#!/bin/sh"
        echo "exec \"$node/bin/node\" \"$dest/$entry\" \"\$@\""
      } > "$out/bin/$mainProgram"
      chmod +x "$out/bin/$mainProgram"
    '';
  };
in
drv
// {
  meta = {
    platforms = [ "x86_64-linux" ];
    inherit mainProgram;
  }
  // meta;
  passthru =
    (if category == null then { } else { inherit category; })
    // (if updater == null then { } else { inherit updater; });
  fhs = {
    kind = "patchelf";
    inherit libpath mainProgram;
    ignoreMissing = "";
  };
}
// (if updater == null then { } else { inherit updater; })
