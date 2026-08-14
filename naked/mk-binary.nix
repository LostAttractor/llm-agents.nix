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
# runtimeBins: extra prebuilt binaries bundled onto PATH (e.g. a vendored
# ripgrep), formatelf'd if dynamic.
{
  pname,
  version,
  src,
  unpack ? "none", # "none" | "zip" | "tar"
  binary ? pname, # path to the main binary after unpack
  mainProgram ? pname,
  kind ? "patchelf", # "patchelf" | "loader"
  libs ? [ ], # extra store paths whose /lib joins the rpath/library-path
  runtimeBins ? [ ], # [{ name; src; }] prebuilt binaries bundled onto PATH
  system,
}:
let
  seed = import ./seed.nix { inherit system; };
  mkNaked = import ./mk-naked.nix;
  sys = (import ./systems.nix).${system};
  pins = sys.pins;

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
      inherit src;
      busybox = seed.busybox;
      glibc = pins.glibc;
      formatelf = pins.formatelf;
      inherit libpath;
      loader = "${pins.glibc}/lib/${sys.loader}";
      unpackKind = unpack;
      binaryPath = binary;
      inherit mainProgram kind;
      runtimeBins = builtins.concatStringsSep "\n" (map (b: "${b.name}=${b.src}") runtimeBins);
    };
    script = ''
      mkdir -p "$out/bin" "$out/libexec"

      case "$unpackKind" in
        none) cp "$src" "$out/libexec/$mainProgram" ;;
        zip)  unzip -q "$src"; cp "$binaryPath" "$out/libexec/$mainProgram" ;;
        tar)  tar -xf "$src";  cp "$binaryPath" "$out/libexec/$mainProgram" ;;
      esac
      chmod 0755 "$out/libexec/$mainProgram"  # writable so formatelf can rewrite it

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
        fixelf "$out/libexec/$mainProgram"
      fi

      ln -s "$busybox" "$out/libexec/sh"
      {
        echo "#!$out/libexec/sh"
        echo "export PATH=\"$out/libexec\''${PATH:+:\$PATH}\""
        if [ "$kind" = loader ]; then
          echo "exec \"$loader\" --library-path \"$libpath\" \"$out/libexec/$mainProgram\" \"\$@\""
        else
          echo "exec \"$out/libexec/$mainProgram\" \"\$@\""
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
