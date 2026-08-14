# checkFhs: assert a package output does NOT depend on the FHS - every library
# an ELF needs must resolve inside /nix/store, and no ELF is left pointing at a
# host loader we don't control. Catches a prebuilt binary we forgot to patch
# (still on /lib64/ld-linux or a missing lib), which would break on NixOS.
#
# Mechanism-aware, reading `package.fhs` from mkBinary:
#   - patchelf kind: the binary's interpreter must be a store loader and every
#     NEEDED lib must resolve via its own rpath.
#   - loader kind: the wrapper invokes a pinned store loader with an explicit
#     --library-path, so the wrapped binary's own (FHS) interpreter is bypassed
#     - we allow it, and resolve NEEDED against that library-path instead.
let
  mkNaked = import ./mk-naked.nix;
  pinned = import ./pinned.nix;
in
{
  package,
  name,
}:
mkNaked {
  name = "${name}-fhs-check";
  env = {
    inherit package;
    formatelf = "${pinned.formatelf}/bin/formatelf";
    kind = package.fhs.kind or "patchelf";
    libpath = package.fhs.libpath or "";
  };
  script = ''
    fail=0
    for f in $(find -L "$package" -type f 2>/dev/null); do
      [ "$(head -c4 "$f" 2>/dev/null | od -An -tx1 | tr -d ' \n')" = "7f454c46" ] || continue

      rpath=$("$formatelf" --print-rpath "$f" 2>/dev/null || true)
      # effective search path = this ELF's rpath + the package's runtime library-path
      search="$rpath''${libpath:+:$libpath}"

      interp=$("$formatelf" --print-interpreter "$f" 2>/dev/null || true)
      if [ -n "$interp" ]; then
        case "$interp" in
          /nix/store/*) ;;
          *) # a non-store interpreter is only OK if a loader-kind wrapper overrides it
            if [ "$kind" != loader ]; then
              echo "FHS interpreter: $f -> $interp"; fail=1
            fi ;;
        esac
      fi

      old_ifs="$IFS"; IFS=':'
      for d in $search; do
        [ -n "$d" ] || continue
        case "$d" in /nix/store/*) ;; *) echo "FHS lib dir: $f -> $d"; fail=1 ;; esac
      done
      IFS="$old_ifs"

      for lib in $("$formatelf" --print-needed "$f" 2>/dev/null); do
        case "$lib" in ld-linux*) continue ;; esac
        found=0; old_ifs="$IFS"; IFS=':'
        for d in $search; do [ -e "$d/$lib" ] && found=1; done
        IFS="$old_ifs"
        [ "$found" = 1 ] || { echo "unresolved NEEDED: $f needs $lib"; fail=1; }
      done
    done

    if [ "$fail" != 0 ]; then
      echo "FHS check FAILED: $package still depends on the FHS"
      exit 1
    fi
    echo "OK: $package is store-only; every ELF resolves within /nix/store" > "$out"
  '';
}
