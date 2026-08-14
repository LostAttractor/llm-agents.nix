# mkBinary: port a binary-wrapper package onto the naked base, for a given
# system. The nixpkgs-free equivalent of platformSource + autoPatchelf +
# makeWrapper: fetch a prebuilt release artifact, unpack, make it runnable, wrap.
#
# kind:
#   "patchelf" - a normal dynamic ELF: rewrite interpreter/rpath (via formatelf)
#                to the pinned glibc (+ any extra libs).
#   "loader"   - a bun --compile binary: its appended JS payload segfaults on any
#                ELF rewrite, so leave it byte-intact and invoke the pinned
#                loader through a wrapper instead.
#
# installDir: dir-install mode - copy the whole extracted <installDir> tree to
#   $out (the entrypoint is one file inside it), not just a single binary.
# runtimeBins: prebuilt binaries bundled onto PATH (e.g. a vendored ripgrep).
# runtimePkgs: pinned nixpkgs tools whose /bin joins PATH (e.g. pins.ripgrep).
{
  pname,
  version,
  src,
  unpack ? "none", # "none" | "zip" | "tar"
  binary ? pname, # path to the main binary after unpack (single-file mode)
  installDir ? null, # dir to copy wholesale (dir-install mode); entrypoint is mainProgram inside it
  mainProgram ? pname,
  kind ? "patchelf", # "patchelf" | "loader"
  libs ? [ ], # extra store paths whose /lib joins the rpath/library-path
  runtimeBins ? [ ], # [{ name; src; }] prebuilt binaries bundled onto PATH
  runtimePkgs ? [ ], # pinned store paths whose /bin joins PATH
  system,
  pins,
}:
let
  seed = import ./seed.nix { inherit system; };
  mkNaked = import ./mk-naked.nix;
  sys = (import ./systems.nix).${system};

  libpath = builtins.concatStringsSep ":" (
    map (p: "${p}/lib") (
      [
        pins.glibc
        pins.gccLib
      ]
      ++ libs
    )
  );
  drv = mkNaked {
    inherit system;
    name = "${pname}-${version}";
    env = {
      inherit
        src
        pname
        mainProgram
        kind
        ;
      busybox = seed.busybox;
      glibc = pins.glibc;
      formatelf = pins.formatelf;
      inherit libpath;
      loader = "${pins.glibc}/lib/${sys.loader}";
      unpackKind = unpack;
      binaryPath = binary;
      installDir = if installDir == null then "" else installDir;
      runtimeBins = builtins.concatStringsSep "\n" (map (b: "${b.name}=${b.src}") runtimeBins);
      runtimePath = builtins.concatStringsSep ":" (map (p: "${p}/bin") runtimePkgs);
    };
    script = ''
      mkdir -p "$out/bin" "$out/libexec"

      case "$unpackKind" in
        none) ;;
        zip)  unzip -q "$src" ;;
        tar)  tar -xf "$src" ;;
      esac

      if [ -n "$installDir" ]; then
        # dir-install: copy the whole tree; entrypoint is one file inside it
        bindir="$out/libexec/$pname"
        mkdir -p "$bindir"
        cp -r "$installDir/." "$bindir/"
      else
        bindir="$out/libexec"
        if [ "$unpackKind" = none ]; then cp "$src" "$bindir/$mainProgram"; else cp "$binaryPath" "$bindir/$mainProgram"; fi
      fi
      chmod -R u+w "$bindir"
      chmod 0755 "$bindir/$mainProgram"

      # patch a binary iff it is dynamic (has an interpreter)
      fixelf() {
        if "$formatelf/bin/formatelf" --print-interpreter "$1" >/dev/null 2>&1; then
          "$formatelf/bin/formatelf" --set-interpreter "$loader" --set-rpath "$libpath" "$1"
        fi
      }

      printf '%s\n' "$runtimeBins" | while IFS='=' read -r rname rpath; do
        [ -n "$rname" ] || continue
        cp "$rpath" "$out/libexec/$rname"
        chmod 0755 "$out/libexec/$rname"
        fixelf "$out/libexec/$rname"
      done

      if [ "$kind" = patchelf ]; then
        if [ -n "$installDir" ]; then
          # dir-install: the entrypoint may be a script wrapping bundled ELFs
          # (e.g. a vendored node), so patch every ELF in the tree.
          for f in $(find "$bindir" -type f); do
            [ "$(head -c4 "$f" 2>/dev/null | od -An -tx1 | tr -d ' \n')" = "7f454c46" ] || continue
            fixelf "$f"
          done
        else
          fixelf "$bindir/$mainProgram"
        fi
      fi

      # wrapper PATH: bundled bins ($out/libexec + bindir) then pinned tools
      wrapperpath="$out/libexec:$bindir"
      [ -n "$runtimePath" ] && wrapperpath="$wrapperpath:$runtimePath"

      ln -s "$busybox" "$out/libexec/sh"
      {
        echo "#!$out/libexec/sh"
        echo "export PATH=\"$wrapperpath\''${PATH:+:\$PATH}\""
        if [ "$kind" = loader ]; then
          echo "exec \"$loader\" --library-path \"$libpath\" \"$bindir/$mainProgram\" \"\$@\""
        else
          echo "exec \"$bindir/$mainProgram\" \"\$@\""
        fi
      } > "$out/bin/$mainProgram"
      chmod +x "$out/bin/$mainProgram"
    '';
  };
in
drv
// {
  fhs = {
    inherit kind libpath mainProgram;
  };
}
