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
  # { <system> = "<platform-token>"; } - the multi-platform map (mirrors
  # lib/platform-source.nix). urlTemplate's {platform} token is filled per
  # system, and meta.platforms is its key set so the flake gates unsupported
  # systems out before src is forced. null = single-platform (urlTemplate has
  # the platform baked in, available only on `system`).
  platforms ? null,
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
  extraArgs ? [ ], # flags appended to the wrapped exec, before "$@" (e.g. --no-auto-update)
  aliases ? [ ], # extra $out/bin/<name> wrappers, each exec'd with argv0=<name>
  # Package-level metadata carried onto the naked derivation so the flake's
  # meta-completeness / README / updater machinery treat it like any package.
  category ? null, # passthru.category
  updater ? null, # passthru.updater (declarative updater config, already built by mkUpdater)
  meta ? { }, # merged into output meta (description/homepage/changelog/license/sourceProvenance/maintainers)
  system,
  pins,
}:
let
  seed = import ../seed.nix { inherit system; };
  mkNaked = import ./naked.nix;
  sys = (import ../systems.nix).${system};
  isDarwin = builtins.match ".*-darwin" system != null;

  # Reuse the repo's shared hashes.json (the same file nix-update bumps) instead
  # of a duplicated literal hash. url comes from the shared interpolate template.
  fetchurl = import ../fetchurl.nix;
  interpolate = import ../interpolate.nix;
  hashData = if hashesFile == null then null else builtins.fromJSON (builtins.readFile hashesFile);
  resolvedVersion = if hashData == null then version else hashData.version;
  # A platforms entry is either a string (shorthand for the {platform} token) or
  # an attrset of arbitrary URL vars (e.g. { os = "linux"; cpu = "x86_64"; } for
  # a "{os}/{cpu}" template) - same contract as lib/platform-source.nix.
  platformVars =
    if platforms == null then
      { }
    else
      let
        entry = platforms.${system};
      in
      if builtins.isAttrs entry then entry else { platform = entry; };
  resolvedSrc =
    if src != null then
      src
    else
      fetchurl {
        url = interpolate urlTemplate ({ version = resolvedVersion; } // platformVars);
        hash = hashData.hashes.${system} or hashData.${system};
      };

  # Darwin Mach-O binaries link the always-present system libSystem via dyld -
  # no rpath rewriting, no loader, no glibc/formatelf pins. libpath is Linux-only.
  libpath =
    if isDarwin then
      ""
    else
      builtins.concatStringsSep ":" (
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
      os = if isDarwin then "darwin" else "linux";
      entry = if entrypoint == null then mainProgram else entrypoint;
      busybox = if isDarwin then "" else seed.busybox;
      glibc = if isDarwin then "" else pins.glibc;
      formatelf = if isDarwin then "" else pins.formatelf;
      inherit libpath;
      loader = if isDarwin then "" else "${pins.glibc}/lib/${sys.loader}";
      unpackKind = unpack;
      binaryPath = binary;
      installDir = if installDir == null then "" else installDir;
      # __structuredAttrs: pass real structured data, not string-munged env vars.
      inherit runtimeBins; # [ { name; src; } ]
      inherit setEnv; # { VAR = "val"; }
      inherit extraArgs aliases; # wrapper flags + argv0-aliased wrappers
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
        if $attrs.os == "linux" { do $fixelf $"($out)/libexec/($b.name)" }
      }

      # ELF patching is Linux-only; Mach-O binaries need no rpath rewriting.
      if $attrs.kind == "patchelf" and $attrs.os == "linux" {
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

      # wrapper PATH: bundled bins ($out/libexec + bindir) then pinned tools.
      # let (not mut): the closure below captures it, and nushell closures
      # cannot capture mutable variables.
      let wrapperpath = (if ($attrs.runtimePath | is-not-empty) { $"($out)/libexec:($bindir):($attrs.runtimePath)" } else { $"($out)/libexec:($bindir)" })

      # wrapper interpreter: Linux uses the bundled busybox sh (nixpkgs-free);
      # darwin uses the system /bin/sh (always present, like libSystem).
      let sh = (
        if $attrs.os == "linux" {
          ^ln -s $attrs.busybox $"($out)/libexec/sh"
          $"($out)/libexec/sh"
        } else { "/bin/sh" }
      )

      # immutable alias of the (mut) bindir so the closure can capture it
      let wbindir = $bindir

      # extra flags appended to the wrapped binary before "$@" (e.g. --no-auto-update)
      let flags = ($attrs.extraArgs | each {|a| $'"($a)"' } | str join " ")

      # write one wrapper: a /bin/sh script that sets PATH/env then exec's the
      # binary. argv0 lets aliases (e.g. `agent`) make the binary see a
      # different name; `exec -a` is supported by both busybox ash and macOS sh.
      let mkwrapper = {|wname: string, argv0: string|
        mut lines = [ $"#!($sh)" ]
        $lines = ($lines | append $'export PATH="($wrapperpath)''${PATH:+:$PATH}"')
        if ($attrs.setEnv | is-not-empty) {
          for e in ($attrs.setEnv | transpose key value) {
            $lines = ($lines | append $'export ($e.key)=($e.value)')
          }
        }
        let tail = (if ($flags | is-empty) { ' "$@"' } else { $' ($flags) "$@"' })
        # loader-invoke is Linux-only (bun --compile); darwin execs directly.
        if $attrs.kind == "loader" and $attrs.os == "linux" {
          $lines = ($lines | append $'exec -a "($argv0)" "($attrs.loader)" --library-path "($attrs.libpath)" "($wbindir)/($attrs.entry)"($tail)')
        } else {
          $lines = ($lines | append $'exec -a "($argv0)" "($wbindir)/($attrs.entry)"($tail)')
        }
        (($lines | str join "\n") + "\n") | save --raw --force $"($out)/bin/($wname)"
        ^chmod +x $"($out)/bin/($wname)"
      }

      do $mkwrapper $attrs.mainProgram $attrs.mainProgram
      for a in $attrs.aliases { do $mkwrapper $a $a }
    '';
  };
in
drv
// {
  # meta so the flake's availableOn gating + checks treat it like a package.
  # platforms is the full supported set (map keys) so an unsupported current
  # system filters out before src is forced; single-platform builds report
  # just [ system ]. Reading .meta never forces the derivation (lazy `//`).
  # The caller's meta (description/homepage/changelog/license/sourceProvenance/
  # maintainers) is merged on top; platforms/mainProgram are the defaults.
  meta = {
    platforms = if platforms == null then [ system ] else builtins.attrNames platforms;
    inherit mainProgram;
  }
  // meta;
  # passthru: category (README + meta-completeness) and the declarative updater
  # config. `updater` is also lifted top-level because the flake's
  # withUpdateScript keys on `pkg ? updater`.
  passthru =
    (if category == null then { } else { inherit category; })
    // (if updater == null then { } else { inherit updater; });
}
// (if updater == null then { } else { inherit updater; })
// {
  fhs = {
    inherit kind libpath mainProgram;
    ignoreMissing = builtins.concatStringsSep " " ignoreMissing;
  };
}
