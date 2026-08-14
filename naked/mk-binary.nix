# mkBinary: port a binary-wrapper package onto the naked base. This is the
# nixpkgs-free equivalent of the platformSource + autoPatchelf + makeWrapper
# pattern that ~17 packages in this repo share: fetch a prebuilt release
# artifact, unpack it, make it runnable, wrap it.
#
# kind:
#   "patchelf" - a normal dynamic ELF: rewrite its interpreter/rpath to the
#                pinned glibc (+ any extra libs).
#   "loader"   - a bun --compile binary: it appends its JS runtime to the ELF
#                tail and recomputes that offset from the file, so patchelf
#                would segfault it. Leave it byte-intact and invoke the pinned
#                loader through a wrapper instead.
#
# runtimeBins: extra prebuilt binaries to bundle onto PATH (e.g. a vendored
# ripgrep), patchelf'd if dynamic.
let
  seed = import ./seed.nix;
  pinned = import ./pinned.nix;
  mkNaked = import ./mk-naked.nix;

  libDirs = extra: builtins.concatStringsSep ":" (map (p: "${p}/lib") ([ pinned.glibc pinned.gccLib ] ++ extra));
in
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
  system ? "x86_64-linux",
}:
mkNaked {
  name = "${pname}-${version}";
  inherit system;
  env = {
    inherit src;
    busybox = seed.busybox;
    glibc = pinned.glibc;
    patchelf = pinned.patchelf;
    libpath = libDirs libs;
    loader = "${pinned.glibc}/lib/ld-linux-x86-64.so.2";
    unpackKind = unpack;
    binaryPath = binary;
    inherit mainProgram kind;
    # runtime bins as "name=storepath" lines
    runtimeBins = builtins.concatStringsSep "\n" (map (b: "${b.name}=${b.src}") runtimeBins);
  };
  script = ''
    mkdir -p "$out/bin" "$out/libexec"

    case "$unpackKind" in
      none) cp "$src" "$out/libexec/$mainProgram" ;;
      zip)  unzip -q "$src"; cp "$binaryPath" "$out/libexec/$mainProgram" ;;
      tar)  tar -xf "$src";  cp "$binaryPath" "$out/libexec/$mainProgram" ;;
    esac
    chmod +x "$out/libexec/$mainProgram"

    # helper: patchelf a binary iff it is dynamic (has an interpreter)
    fixelf() {
      if "$patchelf/bin/patchelf" --print-interpreter "$1" >/dev/null 2>&1; then
        "$patchelf/bin/patchelf" --set-interpreter "$loader" --set-rpath "$libpath" "$1"
      fi
    }

    # bundle vendored runtime binaries onto PATH
    printf '%s\n' "$runtimeBins" | while IFS='=' read -r rname rpath; do
      [ -n "$rname" ] || continue
      cp "$rpath" "$out/libexec/$rname"
      chmod +x "$out/libexec/$rname"
      fixelf "$out/libexec/$rname"
    done

    if [ "$kind" = patchelf ]; then
      fixelf "$out/libexec/$mainProgram"
    fi

    # wrapper: PATH includes bundled bins; loader kind invokes the pinned loader
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
}
