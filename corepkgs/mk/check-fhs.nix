# checkFhs: assert a package output does NOT depend on the FHS - every library
# an ELF needs must resolve inside /nix/store, and no ELF is left on a host
# loader we don't control. The naked equivalent of autoPatchelfHook's guard.
#
# Mechanism-aware (reads package.fhs from mkBinary): patchelf packages resolve
# NEEDED via the ELF rpath; loader packages via the wrapper's --library-path
# (their own FHS interpreter is bypassed by the pinned loader); ignoreMissing
# SONAMEs (a bundled JRE's optional AWT/X11 libs) are allowed to stay unresolved.
#
# Build script is nushell (the mk-naked builder), reading __structuredAttrs.
let
  mkNaked = import ./naked.nix;
in
{
  package,
  name,
  system,
  pins,
}:
mkNaked {
  inherit system;
  name = "${name}-fhs-check";
  env = {
    inherit package;
    formatelf = "${pins.formatelf}/bin/formatelf";
    kind = package.fhs.kind or "patchelf";
    libpath = package.fhs.libpath or "";
    ignoreMissing = package.fhs.ignoreMissing or "";
  };
  script = ''
    let pkg = $attrs.package
    let fe = $attrs.formatelf
    let kind = $attrs.kind
    let libpath = $attrs.libpath
    let ignore = ($attrs.ignoreMissing | split row " " | where {|x| $x != "" })

    mut fail = false
    for f in (^find -L $pkg -type f | lines) {
      let magic = ((^head -c4 $f | ^od -An -tx1) | str replace --all --regex '[^0-9a-f]' "")
      if $magic != "7f454c46" { continue }

      let rpath = (do { ^$fe --print-rpath $f } | complete | get stdout | str trim)
      let search = ((if ($libpath | is-empty) { $rpath } else { $"($rpath):($libpath)" }) | split row ":" | where {|x| $x != "" })

      let interp = (do { ^$fe --print-interpreter $f } | complete | get stdout | str trim)
      if ($interp != "") and (not ($interp | str starts-with "/nix/store/")) {
        if $kind != "loader" {
          print $"FHS interpreter: ($f) -> ($interp)"
          $fail = true
        }
      }

      for d in $search {
        if not ($d | str starts-with "/nix/store/") {
          print $"FHS lib dir: ($f) -> ($d)"
          $fail = true
        }
      }

      for lib in (do { ^$fe --print-needed $f } | complete | get stdout | lines) {
        if ($lib | str starts-with "ld-linux") { continue }
        if ($lib in $ignore) { continue }
        let found = ($search | any {|d| ($"($d)/($lib)" | path exists) })
        if not $found {
          print $"unresolved NEEDED: ($f) needs ($lib)"
          $fail = true
        }
      }
    }

    if $fail {
      print $"FHS check FAILED: ($pkg) still depends on the FHS"
      exit 1
    }
    $"OK: ($pkg) is store-only; every ELF resolves within /nix/store" | save --raw $out
  '';
}
