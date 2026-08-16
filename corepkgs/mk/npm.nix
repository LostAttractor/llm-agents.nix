# mkNpm: build an npm package from source, nixpkgs-free. Deps vendored by
# vendor/npm.nix (a node_modules FOD, our own npmDepsHash). Installs under
# $out/lib/node_modules/<pname>, wraps each package.json "bin". Knobs: binWrappers
# override auto launchers; nativeAddons patchelf bundled *.node/*.bare to pinned glibc.
# node-gyp building an addon from source is out of scope.
{
  pname,
  version,
  src, # fetched source archive (.tar.gz, single top-level dir)
  npmDepsHash, # our node_modules FOD hash (build once with a fake hash to obtain)
  sourceRoot ? null, # subdir holding package.json (relative to the tarball top dir)
  packageLock ? null, # committed package-lock.json to inject (registry tarballs that ship none)
  omitOptional ? false, # drop optionalDependencies (cross-platform prebuilds the package ships but does not need)
  buildScript ? "build", # `npm run <buildScript>`; "" to skip (no build step)
  # Override the auto bin launchers. Attrset { <binname> = { entry = "dist/x.js";
  # nodeFlags ? [ ]; env ? { }; pathAdd ? [ <pin> ]; }; }. entry is relative to
  # the installed package root ($out/lib/node_modules/<pname>).
  binWrappers ? null,
  nativeAddons ? false, # patchelf bundled prebuilt *.node / *.bare addons to the pinned glibc
  addonLibs ? [ ], # extra C-lib pins whose /lib joins the addon rpath
  ignoreMissing ? "", # space-separated SONAMEs a native addon may leave unresolved (fhs allowlist)
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
  inherit (toolchains) node;
  npmVendor = import ../vendor/npm.nix {
    inherit
      src
      npmDepsHash
      sourceRoot
      packageLock
      omitOptional
      system
      node
      ;
  };

  # native addon rpath: pinned glibc + gccLib (+ any extra C-lib pins).
  addonLibPath = builtins.concatStringsSep ":" (map (p: "${p}/lib") addonLibs);
  addonRpath =
    "${pins.glibc}/lib:${pins.gccLib}/lib" + (if addonLibPath == "" then "" else ":${addonLibPath}");

  # Render one custom bin wrapper into a shell block. $node/$dest are build-time
  # shell vars; \$PATH / \$@ stay literal so the emitted wrapper resolves them at runtime.
  renderWrapper =
    name: spec:
    let
      flags = builtins.concatStringsSep " " (spec.nodeFlags or [ ]);
      envs = spec.env or { };
      envEchos = builtins.concatStringsSep "\n" (
        map (k: ''echo 'export ${k}="${builtins.getAttr k envs}"' '') (builtins.attrNames envs)
      );
      pathAdd = spec.pathAdd or [ ];
      pathEcho =
        if pathAdd == [ ] then
          ""
        else
          ''echo "export PATH=\"${builtins.concatStringsSep ":" (map (p: "${p}/bin") pathAdd)}:\$PATH\""'';
    in
    ''
      {
        echo "#!/bin/sh"
      ${envEchos}
      ${pathEcho}
        echo "exec \"$node/bin/node\" ${flags} \"$dest/${spec.entry}\" \"\$@\""
      } > "$out/bin/${name}"
      chmod +x "$out/bin/${name}"
    '';
  customWrapperScript =
    if binWrappers == null then
      ""
    else
      builtins.concatStringsSep "\n" (
        map (n: renderWrapper n (builtins.getAttr n binWrappers)) (builtins.attrNames binWrappers)
      );

  drv = mkDrvSh {
    inherit system;
    name = "${pname}-${version}";
    env = {
      inherit src node pname;
      vendor = npmVendor;
      sourceRoot = if sourceRoot == null then "" else sourceRoot;
      inherit buildScript;
      customBins = if binWrappers == null then "" else "1";
      nativeAddons = if nativeAddons then "1" else "";
      formatelf = pins.formatelf;
      inherit addonRpath;
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
      # `#!/usr/bin/env node` in node_modules/.bin targets to our node. Else
      # `npm run build` -> tsc/esbuild fail with "not found".
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

      # patchelf bundled prebuilt native addons (*.node / *.bare) to the pinned
      # glibc, so they resolve inside the store instead of the host FHS.
      if [ -n "$nativeAddons" ]; then
        find "$dest" \( -name '*.node' -o -name '*.bare' \) -type f | while read -r so; do
          [ "$(head -c4 "$so" | od -An -tx1 | tr -d ' \n')" = "7f454c46" ] || continue
          "$formatelf/bin/formatelf" --force-rpath --set-rpath "$addonRpath" "$so" 2>/dev/null || true
        done
      fi

      if [ -z "$customBins" ]; then
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
      fi

      # caller-supplied wrappers (extra node flags / env / PATH / corrected entry)
      ${customWrapperScript}
    '';
  };
in
drv
// {
  # The wrapper + installed JS have no ELF of their own unless the package
  # bundles native addons, which we patchelf'd above. linux-only for now.
  meta = {
    platforms = [ "x86_64-linux" ];
    inherit mainProgram;
  }
  // meta;
  passthru =
    (if category == null then { } else { inherit category; })
    // (if updater == null then { } else { inherit updater; });
  fhs =
    if nativeAddons then
      {
        kind = "patchelf";
        libpath = addonRpath;
        inherit mainProgram ignoreMissing;
      }
    else
      {
        kind = "static";
        libpath = "";
        inherit mainProgram;
        ignoreMissing = "";
      };
}
// (if updater == null then { } else { inherit updater; })
