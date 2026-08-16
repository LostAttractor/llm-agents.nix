# mkCargo: build a Rust package from source, nixpkgs-free, with the naked rust
# toolchain + `zig cc` as the linker + crates vendored by vendor/cargo.nix.
#
# zig cc can't be handed --dynamic-linker (it re-sub-compiles glibc/compiler_rt
# inheriting the flag, which they reject), so we link normally and POST-LINK
# patch each produced executable with the pinned formatelf: store loader + rpath,
# so build scripts and the final binaries run in the sandbox with no /lib64.
#
# Scope: this handles packages whose Cargo.lock is pure crates.io and that need
# no external C libraries. C-dep crates (-sys: openssl/sqlite/...) and git
# dependencies are NOT handled yet - they need C-lib pins + pkg-config, and a
# git-source vendorer, respectively.
{
  pname,
  version ? null,
  src, # fetched source archive (a .tar.gz with a single top-level dir)
  cargoLock, # path to the package's Cargo.lock
  sourceRoot ? null, # subdir of the source tree holding the workspace/crate (relative to the tarball's top dir), e.g. "rust" / "src-tauri"
  binaries ? [ pname ], # binaries to install from target/release/
  cargoBuildFlags ? [ ], # e.g. [ "--no-default-features" "--features" "x" "-p" "sub" ]
  buildInputs ? [ ], # extra C-library pins whose /lib joins the link path + runtime rpath (for -sys crates linking a system lib)
  # git dependencies Cargo.lock pins to a github repo whose ROOT is a single
  # crate. Each: { crate = "<name>"; source = "<the Cargo.lock source string>";
  # hash = "<SRI of github archive at the resolved rev>"; }. Workspace-member git
  # deps (crate in a subdir) are not handled.
  gitDeps ? [ ],
  openssl ? false, # convenience: wire the pinned openssl (OPENSSL_NO_VENDOR + LIB/INCLUDE dirs) for openssl-sys / native-tls
  extraEnv ? { }, # extra build-time env vars (become derivation env, exported to cargo/build.rs): RUSTC_BOOTSTRAP, a pinned data file path a build.rs reads, a version override, ...
  mainProgram ? builtins.head binaries,
  # Package metadata carried onto the naked derivation (like mkBinary), so the
  # flake's meta-completeness / README / updater machinery treat it normally.
  meta ? { },
  category ? null,
  updater ? null,
  system,
  pins,
  toolchains,
}:
let
  mkNaked = import ./naked-sh.nix;
  cargoVendor = import ../vendor/cargo.nix;
  sys = (import ../seed/systems.nix).${system};
  inherit (toolchains) rust zig;

  gnuTarget = "${sys.zig.platform}-gnu"; # zig cc target
  rustGnu = sys.rust.gnu; # cargo [target.<triple>]

  fetchurl = import ../fetch/fetchurl.nix;
  # Parse one git dep's Cargo.lock source string into the pieces the vendorer +
  # config.toml need. source = "git+<url>[?rev=|?branch=|?tag=<v>]#<resolved-rev>".
  parseGit =
    g:
    let
      m = builtins.match "git\\+(https://[^?#]+)(\\?([^#]*))?#(.*)" g.source;
      url = builtins.elemAt m 0;
      query = builtins.elemAt m 2; # e.g. "rev=abc" / "branch=x" / null
      rev = builtins.elemAt m 3; # resolved commit (the #fragment)
      sourceKey = "git+${url}" + (if query == null then "" else "?${query}");
      kv = if query == null then null else builtins.match "(rev|branch|tag)=(.*)" query;
      fieldLine = if kv == null then "" else "${builtins.elemAt kv 0} = \"${builtins.elemAt kv 1}\"";
    in
    {
      inherit (g) crate;
      inherit
        url
        rev
        sourceKey
        fieldLine
        ;
      archive = fetchurl {
        url = "${url}/archive/${rev}.tar.gz";
        hash = g.hash;
        name = "${g.crate}-${rev}.tar.gz";
      };
    };
  gits = map parseGit gitDeps;
  # a [source."..."] replacement block per git dep, all pointing at the vendor dir
  gitConfig = builtins.concatStringsSep "\n" (
    map (
      g:
      ''
        [source."${g.sourceKey}"]
        git = "${g.url}"
      ''
      + (if g.fieldLine == "" then "" else g.fieldLine + "\n")
      + ''
        replace-with = "vendored"
      ''
    ) gits
  );
  vendor = cargoVendor {
    inherit cargoLock system;
    gitDeps = map (g: { inherit (g) crate archive; }) gits;
  };
  # extra C-library pins (buildInputs + openssl) whose /lib joins the link path
  # and the runtime rpath so -sys crates linking a system lib resolve it.
  extraLibs = buildInputs ++ (if openssl then [ pins.openssl ] else [ ]);
  extraLibPath = builtins.concatStringsSep ":" (map (p: "${p}/lib") extraLibs);
  # the zcc post-link sets rpath to the pinned glibc + gccLib (+ extra C libs)
  libpath =
    "${pins.glibc}/lib:${pins.gccLib}/lib" + (if extraLibPath == "" then "" else ":${extraLibPath}");
  drv = mkNaked {
    inherit system;
    name = if version == null then "${pname}-naked" else "${pname}-${version}";
    env = {
      inherit
        src
        vendor
        rust
        zig
        rustGnu
        gnuTarget
        ;
      installBins = builtins.concatStringsSep " " binaries;
      buildFlags = builtins.concatStringsSep " " cargoBuildFlags;
      cargoLockFile = cargoLock; # copied over the source's lock so the vendored lock is authoritative
      sourceRoot = if sourceRoot == null then "" else sourceRoot;
      glibc = pins.glibc;
      gccLib = pins.gccLib;
      formatelf = pins.formatelf;
      loader = sys.loader;
      inherit extraLibPath;
      useOpenssl = if openssl then "1" else "";
      opensslLibDir = if openssl then "${pins.openssl}/lib" else "";
      opensslIncDir = if openssl then "${pins.opensslDev}/include" else "";
      pkgConfigBin = "${pins.pkgConfig}/bin";
      pkgConfigPath = if openssl then "${pins.opensslDev}/lib/pkgconfig" else "";
    }
    # caller build-time env (RUSTC_BOOTSTRAP, a build.rs data-file path, ...);
    # derivation attrs are the builder's env vars, so these reach cargo/build.rs.
    // extraEnv;
    script = ''
      export HOME="$NIX_BUILD_TOP"
      export CARGO_HOME="$NIX_BUILD_TOP/.cargo"
      export ZIG_GLOBAL_CACHE_DIR="$NIX_BUILD_TOP/zig-cache"
      export PATH="$rust/bin:$zig/bin:$PATH"

      ld="$glibc/lib/$loader"
      libp="$glibc/lib:$gccLib/lib"
      [ -n "$extraLibPath" ] && libp="$libp:$extraLibPath"

      # openssl-sys / native-tls: use the pinned openssl (headers + libs) instead
      # of the vendored openssl-src (whose build.rs needs perl) or a system lib.
      # pkg-config for -sys crates that probe it (openssl-sys, etc.)
      export PATH="$pkgConfigBin:$PATH"
      [ -n "$pkgConfigPath" ] && export PKG_CONFIG_PATH="$pkgConfigPath"
      # When linking a pinned shared C lib (openssl's libcrypto.so), that lib has
      # its OWN undefined glibc refs (pthread_mutex_trylock@GLIBC_2.34, ...). They
      # resolve at runtime (glibc is in the rpath), so relax zig/lld's default
      # --no-allow-shlib-undefined at link time.
      if [ -n "$extraLibPath" ]; then
        export RUSTFLAGS="-C link-arg=-Wl,--allow-shlib-undefined''${RUSTFLAGS:+ $RUSTFLAGS}"
      fi
      if [ -n "$useOpenssl" ]; then
        export OPENSSL_NO_VENDOR=1
        export OPENSSL_LIB_DIR="$opensslLibDir"
        export OPENSSL_INCLUDE_DIR="$opensslIncDir"
      fi

      # zig cc wrapper: force the glibc target (else zig falls back to musl and
      # rust's gnu std can't resolve gnu_get_libc_version/mmap64), then POST-LINK
      # patch each produced executable with the pinned formatelf (skip -shared:
      # dylibs have no interpreter).
      cat > "$NIX_BUILD_TOP/zcc" <<EOF
      #!/bin/sh
      # cc crate (-sys build scripts) passes its own --target=<triple> and -m64,
      # which clash with our forced -target; drop them. Track -c so we only
      # post-link-patch actual executables, not compiled .o objects. (nix store
      # paths have no spaces, so unquoted \$filtered is safe.)
      filtered=
      compile=0
      for a in "\$@"; do
        case "\$a" in
          --target=*|-m64|-m32) continue ;;
          -c) compile=1 ;;
        esac
        filtered="\$filtered \$a"
      done
      "$zig/bin/zig" cc -target ${gnuTarget} \$filtered || exit \$?
      [ "\$compile" -eq 1 ] && exit 0
      shared=0; out=""; prev=""
      for a in "\$@"; do
        [ "\$a" = "-shared" ] && shared=1
        [ "\$prev" = "-o" ] && out="\$a"
        prev="\$a"
      done
      if [ "\$shared" -eq 0 ] && [ -n "\$out" ] && [ -f "\$out" ]; then
        "$formatelf/bin/formatelf" --set-interpreter "$ld" --force-rpath --set-rpath "$libp" "\$out" 2>/dev/null || true
      fi
      EOF
      chmod +x "$NIX_BUILD_TOP/zcc"
      export CC="$NIX_BUILD_TOP/zcc"

      # cc-crate (-sys build scripts) archives compiled .o into .a with `ar` and
      # `ranlib`; busybox ar cannot create archives, so provide zig's llvm-ar/
      # ranlib. Put them (and zcc) on PATH so bare `ar`/`cc` invocations resolve.
      for t in ar ranlib; do
        {
          echo "#!/bin/sh"
          echo "exec \"$zig/bin/zig\" $t \"\$@\""
        } > "$NIX_BUILD_TOP/$t"
        chmod +x "$NIX_BUILD_TOP/$t"
      done
      export AR="$NIX_BUILD_TOP/ar"
      export PATH="$NIX_BUILD_TOP:$PATH"

      tar -xzf "$src"
      cd "$(tar -tzf "$src" | head -1 | cut -d/ -f1)"
      [ -n "$sourceRoot" ] && cd "$sourceRoot"

      # Make the vendored lock authoritative: copy our Cargo.lock over the
      # source's (they are usually identical; this also fixes tarballs whose
      # in-tree lock is stale relative to Cargo.toml). Drop --locked since the
      # lock is now ours and all deps are vendored + --offline.
      cp "$cargoLockFile" Cargo.lock
      chmod u+w Cargo.lock

      mkdir -p .cargo
      cat > .cargo/config.toml <<EOF
      [source.crates-io]
      replace-with = "vendored"
      [source.vendored]
      directory = "$vendor"
      ${gitConfig}
      [target.${rustGnu}]
      linker = "$NIX_BUILD_TOP/zcc"
      EOF

      cargo build --release --offline $buildFlags

      mkdir -p "$out/bin"
      for b in $installBins; do
        cp "target/release/$b" "$out/bin/$b"
      done
    '';
  };
in
drv
// {
  # rust source builds are linux-only for now (the naked rust + zig toolchains
  # are Linux); callers can widen meta.platforms once aarch64 is verified.
  meta = {
    platforms = [ "x86_64-linux" ];
    inherit mainProgram;
  }
  // meta;
  passthru =
    (if category == null then { } else { inherit category; })
    // (if updater == null then { } else { inherit updater; });
  # the produced binaries are patchelf'd to the pinned glibc/gccLib, so the FHS
  # check treats them like a kind = "patchelf" mkBinary output.
  fhs = {
    kind = "patchelf";
    inherit libpath mainProgram;
    ignoreMissing = "";
  };
}
// (if updater == null then { } else { inherit updater; })
