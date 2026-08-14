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
  # Source: either a literal src+version, OR reuse the repo's shared source of
  # truth - hashesFile (packages/<name>/hashes.json: {version, hashes.<system>})
  # + urlTemplate (interpolated with {version}). The latter means no duplicated
  # hash/version that drifts when nix-update bumps the real package.
  version ? null,
  src ? null,
  hashesFile ? null,
  urlTemplate ? null,
  unpack ? "none", # "none" | "zip" | "tar"
  binary ? pname, # path to the main binary after unpack (single-file mode)
  installDir ? null, # dir to copy wholesale (dir-install mode)
  mainProgram ? pname, # name of the wrapper in $out/bin
  entrypoint ? null, # path to the real binary inside the tree (dir-install with a nested launcher, e.g. "bin/junie"); defaults to mainProgram
  kind ? "patchelf", # "patchelf" | "loader"
  libs ? [ ], # extra store paths whose /lib joins the rpath/library-path
  runtimeBins ? [ ], # [{ name; src; }] prebuilt binaries bundled onto PATH
  runtimePkgs ? [ ], # pinned store paths whose /bin joins PATH
  ignoreMissing ? [ ], # SONAMEs allowed to stay unresolved (optional deps of a bundled JRE etc.)
  setEnv ? { }, # { VAR = "val"; } exported in the wrapper before exec
  system,
  pins,
}:
let
  seed = import ./seed.nix { inherit system; };
  mkNaked = import ./mk-naked.nix;
  sys = (import ./systems.nix).${system};

  # Reuse the repo's shared hashes.json (the same file nix-update bumps) instead
  # of a duplicated literal hash. url comes from the shared interpolate template.
  fetchurl = import ./fetchurl.nix;
  interpolate = import ../lib/interpolate.nix;
  hashData = if hashesFile == null then null else builtins.fromJSON (builtins.readFile hashesFile);
  resolvedVersion = if hashData == null then version else hashData.version;
  resolvedSrc =
    if src != null then
      src
    else
      fetchurl {
        url = interpolate urlTemplate { version = resolvedVersion; };
        hash = hashData.hashes.${system} or hashData.${system};
      };

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
    name = "${pname}-${resolvedVersion}";
    env = {
      src = resolvedSrc;
      inherit
        pname
        mainProgram
        kind
        ;
      entry = if entrypoint == null then mainProgram else entrypoint;
      busybox = seed.busybox;
      glibc = pins.glibc;
      formatelf = pins.formatelf;
      inherit libpath;
      loader = "${pins.glibc}/lib/${sys.loader}";
      unpackKind = unpack;
      binaryPath = binary;
      installDir = if installDir == null then "" else installDir;
      # __structuredAttrs: pass real structured data, not string-munged env vars.
      inherit runtimeBins; # [ { name; src; } ]
      inherit setEnv; # { VAR = "val"; }
      runtimePath = builtins.concatStringsSep ":" (map (p: "${p}/bin") runtimePkgs);
    };
    # Nushell builder (see mk-naked.nix): `$attrs` is the JSON attrs record,
    # `$out` the output path, busybox applets are external `^cmd`s on PATH.
    script = ''
      mkdir $"($out)/bin" $"($out)/libexec"

      let formatelf = $"($attrs.formatelf)/bin/formatelf"

      # patch a binary iff it is dynamic (has an interpreter)
      let fixelf = {|f|
        if ((^$formatelf --print-interpreter $f | complete).exit_code == 0) {
          ^$formatelf --set-interpreter $attrs.loader --set-rpath $attrs.libpath $f
        }
      }

      if $attrs.unpackKind == "zip" {
        ^unzip -q $attrs.src
      } else if $attrs.unpackKind == "tar" {
        ^tar -xf $attrs.src
      }

      mut bindir = $"($out)/libexec"
      if ($attrs.installDir | is-not-empty) {
        # dir-install: copy the whole tree; entrypoint is one file inside it
        $bindir = $"($out)/libexec/($attrs.pname)"
        mkdir $bindir
        ^cp -r $"($attrs.installDir)/." $bindir
      } else {
        if $attrs.unpackKind == "none" {
          ^cp $attrs.src $"($bindir)/($attrs.entry)"
        } else {
          ^cp $attrs.binaryPath $"($bindir)/($attrs.entry)"
        }
      }
      ^chmod -R u+w $bindir
      ^chmod 0755 $"($bindir)/($attrs.entry)"

      # bundle prebuilt binaries onto PATH (e.g. a vendored ripgrep)
      for b in $attrs.runtimeBins {
        ^cp $b.src $"($out)/libexec/($b.name)"
        ^chmod 0755 $"($out)/libexec/($b.name)"
        do $fixelf $"($out)/libexec/($b.name)"
      }

      if $attrs.kind == "patchelf" {
        if ($attrs.installDir | is-not-empty) {
          # dir-install: patch every ELF in the tree - executables get the loader
          # + rpath, shared libs just get rpath. The rpath includes every dir in
          # the tree that holds a .so (so intra-tree deps like a JRE's libjli.so
          # resolve) followed by the pinned libs.
          let treelibs = (
            ^find $bindir -name '*.so*' -type f
            | lines
            | each {|so| $"($so | path dirname):" }
            | uniq
            | str join ""
          )
          let rp = $treelibs + $attrs.libpath
          for f in (^find $bindir -type f | lines) {
            let magic = (^head -c4 $f | ^od -An -tx1 | str replace --all --regex '\s' "")
            if $magic == "7f454c46" {
              if ((^$formatelf --print-interpreter $f | complete).exit_code == 0) {
                ^$formatelf --set-interpreter $attrs.loader --set-rpath $rp $f | complete | ignore
              } else {
                ^$formatelf --set-rpath $rp $f | complete | ignore
              }
            }
          }
        } else {
          do $fixelf $"($bindir)/($attrs.entry)"
        }
      }

      # wrapper PATH: bundled bins ($out/libexec + bindir) then pinned tools
      mut wrapperpath = $"($out)/libexec:($bindir)"
      if ($attrs.runtimePath | is-not-empty) {
        $wrapperpath = $"($wrapperpath):($attrs.runtimePath)"
      }

      ^ln -s $attrs.busybox $"($out)/libexec/sh"

      # the wrapper is itself a /bin/sh script (shebang -> the busybox sh symlink)
      mut lines = [ $"#!($out)/libexec/sh" ]
      $lines = ($lines | append $'export PATH="($wrapperpath)''${PATH:+:$PATH}"')
      if ($attrs.setEnv | is-not-empty) {
        for e in ($attrs.setEnv | transpose key value) {
          $lines = ($lines | append $'export ($e.key)=($e.value)')
        }
      }
      if $attrs.kind == "loader" {
        $lines = ($lines | append $'exec "($attrs.loader)" --library-path "($attrs.libpath)" "($bindir)/($attrs.entry)" "$@"')
      } else {
        $lines = ($lines | append $'exec "($bindir)/($attrs.entry)" "$@"')
      }
      (($lines | str join "\n") + "\n") | save --raw --force $"($out)/bin/($attrs.mainProgram)"
      ^chmod +x $"($out)/bin/($attrs.mainProgram)"
    '';
  };
in
drv
// {
  fhs = {
    inherit kind libpath mainProgram;
    ignoreMissing = builtins.concatStringsSep " " ignoreMissing;
  };
}
