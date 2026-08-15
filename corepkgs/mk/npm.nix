# mkNpm: build an npm package from source, nixpkgs-free, with the naked node
# toolchain. Deps are vendored by vendor/npm.nix (a node_modules FOD with a
# committed npmDepsHash - our own, not nixpkgs', since we vendor node_modules
# rather than the npm cache). Runs the build script, installs the package under
# $out/lib/node_modules/<pname>, and wraps each package.json "bin" as a
# $out/bin/<name> node launcher. Pure-JS packages; native-module (node-gyp)
# packages are out of scope for now.
{
  pname,
  version,
  src, # fetched source archive (.tar.gz, single top-level dir)
  npmDepsHash, # our node_modules FOD hash (build once with a fake hash to obtain)
  sourceRoot ? null, # subdir holding package.json (relative to the tarball top dir)
  packageLock ? null, # committed package-lock.json to inject (registry tarballs that ship none)
  buildScript ? "build", # `npm run <buildScript>`; "" to skip (no build step)
  mainProgram ? pname,
  meta ? { },
  category ? null,
  updater ? null,
  system,
  pins,
}:
let
  mkNaked = import ./naked-sh.nix;
  node = import ../toolchains/node.nix { inherit system pins; };
  npmVendor = import ../vendor/npm.nix {
    inherit
      src
      npmDepsHash
      sourceRoot
      packageLock
      system
      pins
      ;
  };
  drv = mkNaked {
    inherit system;
    name = "${pname}-${version}";
    env = {
      inherit src node pname;
      vendor = npmVendor;
      sourceRoot = if sourceRoot == null then "" else sourceRoot;
      inherit buildScript;
    };
    script = ''
      export HOME="$NIX_BUILD_TOP"
      export npm_config_cache="$NIX_BUILD_TOP/.npm"
      export npm_config_update_notifier=false npm_config_fund=false npm_config_audit=false
      export PATH="$node/bin:$PATH"

      tar -xzf "$src"
      cd "$(tar -tzf "$src" | head -1 | cut -d/ -f1)"
      [ -n "$sourceRoot" ] && cd "$sourceRoot"

      # drop in the vendored node_modules (the FOD is read-only)
      cp -r "$vendor" node_modules
      chmod -R u+w node_modules

      # patchShebangs: the sandbox has no /usr/bin/env, so rewrite every
      # `#!/usr/bin/env node` in node_modules/.bin targets to our node. Without
      # this, `npm run build` -> tsc/esbuild fail with "not found".
      npm_cli="$node/lib/node_modules/npm/bin/npm-cli.js"
      for l in node_modules/.bin/*; do
        [ -e "$l" ] || continue
        t=$(readlink -f "$l" 2>/dev/null) || continue
        [ -f "$t" ] || continue
        case "$(head -1 "$t" 2>/dev/null)" in
          "#!/usr/bin/env node"*|"#! /usr/bin/env node"*|"#!/usr/bin/node"*)
            sed -i "1s|.*|#!$node/bin/node|" "$t" ;;
        esac
      done

      # build (tsc/esbuild/... via the package's own script). Invoke npm through
      # node (the `npm` bin symlink has the same /usr/bin/env shebang problem).
      [ -n "$buildScript" ] && "$node/bin/node" "$npm_cli" run "$buildScript"

      # install the whole package under $out/lib/node_modules/<pname>
      dest="$out/lib/node_modules/$pname"
      mkdir -p "$dest" "$out/bin"
      cp -r . "$dest/"

      # wrap each package.json "bin" as a node launcher on $out/bin
      node -e '
        const p = require("./package.json");
        let bin = p.bin || {};
        if (typeof bin === "string") bin = { [p.name.replace(/^@[^/]+\//,"")]: bin };
        for (const [k, v] of Object.entries(bin)) console.log(k + " " + String(v).replace(/^\.\//, ""));
      ' | while read -r name entry; do
        [ -n "$name" ] || continue
        {
          echo "#!/bin/sh"
          echo "exec \"$node/bin/node\" \"$dest/$entry\" \"\$@\""
        } > "$out/bin/$name"
        chmod +x "$out/bin/$name"
      done
    '';
  };
in
drv
// {
  # node runtime is dynamically linked (patchelf'd in the toolchain); the wrapper
  # + installed JS have no ELF of their own, so the FHS check is effectively about
  # the node toolchain, which is already store-only. linux-only for now.
  meta = {
    platforms = [ "x86_64-linux" ];
    inherit mainProgram;
  }
  // meta;
  passthru =
    (if category == null then { } else { inherit category; })
    // (if updater == null then { } else { inherit updater; });
  fhs = {
    kind = "static";
    libpath = "";
    inherit mainProgram;
    ignoreMissing = "";
  };
}
// (if updater == null then { } else { inherit updater; })
