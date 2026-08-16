# mkBun: build a bun project from source, nixpkgs-free, with the naked bun
# toolchain. Deps are vendored by vendor/bun.nix (a node_modules FOD, our own
# bunDepsHash). We install the app + node_modules under $out/lib/<pname> and wrap
# `bun run <entry>` as $out/bin/<mainProgram> - the same shape nixpkgs uses for
# bun CLIs (makeWrapper bun --add-flags <entry>).
#
# NOT `bun build --compile`: that reads process.execPath to find its base binary,
# but the naked bun toolchain runs via the pinned glibc loader (execPath = the
# loader), so --compile fails with BunSectionNotFound - and bun can't be
# patchelf'd (its tail-appended runtime breaks on any ELF rewrite). Packages that
# truly need the single compiled binary (e.g. one that walks execPath for bundled
# assets) stay on nixpkgs. Bundled prebuilt *.node native addons are patchelf'd
# to the pinned glibc (like mkNpm's nativeAddons).
{
  pname,
  version,
  src, # fetched source archive (.tar.gz, single top-level dir)
  bunDepsHash, # our node_modules FOD hash (build once with a fake hash to obtain)
  entry, # script bun runs, relative to the app root (e.g. "src/index.ts")
  buildScript ? null, # optional pre-run build, `bun <buildScript>` (e.g. a tailwind/asset step)
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
  mkNaked = import ./naked-sh.nix;
  inherit (toolchains) bun;
  vendor = import ../vendor/bun.nix {
    inherit
      src
      bunDepsHash
      sourceRoot
      system
      bun
      ;
  };
  # native addon rpath: pinned glibc + gccLib (libstdc++/libgcc_s for *.node)
  libpath = "${pins.glibc}/lib:${pins.gccLib}/lib";
  drv = mkNaked {
    inherit system;
    name = "${pname}-${version}";
    env = {
      inherit
        src
        bun
        vendor
        pname
        mainProgram
        entry
        ;
      buildScript = if buildScript == null then "" else buildScript;
      sourceRoot = if sourceRoot == null then "" else sourceRoot;
      formatelf = pins.formatelf;
      inherit libpath;
    };
    script = ''
      export HOME="$NIX_BUILD_TOP"
      export PATH="$bun/bin:$PATH"
      export LD_LIBRARY_PATH="$libpath"
      export BUN_INSTALL="$NIX_BUILD_TOP/.bun"
      export BUN_TMPDIR="$NIX_BUILD_TOP/.bun-tmp"
      mkdir -p "$BUN_TMPDIR"

      tar -xzf "$src"
      cd "$(tar -tzf "$src" | head -1 | cut -d/ -f1)"
      [ -n "$sourceRoot" ] && cd "$sourceRoot"

      # drop in the vendored node_modules (the FOD is read-only)
      cp -r "$vendor" node_modules
      chmod -R u+w node_modules

      # bun's offline resolver refuses semver ranges (^/~) when only the pinned
      # version is present; collapse them to exact pins so bun skips the (blocked)
      # registry lookup.
      for f in package.json packages/*/package.json bun.lock; do
        [ -f "$f" ] && sed -i 's/: "\^/: "/g; s/: "~/: "/g' "$f"
      done

      # optional pre-run build (assets/tailwind/...) in place
      [ -n "$buildScript" ] && bun $buildScript

      # install the whole app (source + node_modules) under $out/lib/<pname>
      dest="$out/lib/$pname"
      mkdir -p "$dest" "$out/bin"
      cp -r . "$dest/"

      # patchelf bundled prebuilt native addons (*.node) to the pinned glibc so
      # they resolve inside the store instead of the host FHS.
      find "$dest" -name '*.node' -type f | while read -r so; do
        [ "$(head -c4 "$so" | od -An -tx1 | tr -d ' \n')" = "7f454c46" ] || continue
        "$formatelf/bin/formatelf" --force-rpath --set-rpath "$libpath" "$so" 2>/dev/null || true
      done

      # wrapper: run the entry on the pinned bun toolchain
      {
        echo "#!/bin/sh"
        echo "exec \"$bun/bin/bun\" run \"$dest/$entry\" \"\$@\""
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
  # $out has no ELF of its own; any bundled native *.node addon is patchelf'd to
  # the pinned glibc, and the bun runtime it runs on is already store-only.
  fhs = {
    kind = "patchelf";
    inherit libpath mainProgram;
    ignoreMissing = "";
  };
}
// (if updater == null then { } else { inherit updater; })
