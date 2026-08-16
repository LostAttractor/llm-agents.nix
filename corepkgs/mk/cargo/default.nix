# mkCargo: build a Rust package from source, nixpkgs-free. rust toolchain +
# `zig cc` as linker + crates vendored by vendor/cargo.
#
# zig cc can't take --dynamic-linker (it re-sub-compiles glibc/compiler_rt, which
# inherit and reject the flag), so link normally and POST-LINK patch each
# executable with formatelf (store loader + rpath) to run without /lib64.
#
# Handles pure-crates.io Cargo.lock deps. C-lib pins (buildInputs/openssl) and
# github-archive gitDeps are supported; -sys crates needing unpinned system libs
# and workspace-member git deps are not.
{
  pname,
  version ? null,
  src, # fetched source archive (a .tar.gz with a single top-level dir)
  cargoLock, # path to the package's Cargo.lock
  patches ? [ ], # patch files applied (patch -p1) in the source before the build
  sourceRoot ? null, # subdir of the source tree holding the workspace/crate (relative to the tarball's top dir), e.g. "rust" / "src-tauri"
  binaries ? [ pname ], # binaries to install from target/release/
  cargoBuildFlags ? [ ], # e.g. [ "--no-default-features" "--features" "x" "-p" "sub" ]
  buildInputs ? [ ], # extra C-library pins whose /lib joins the link path + runtime rpath (for -sys crates linking a system lib)
  # git deps Cargo.lock pins to a github repo whose ROOT is a single crate. Each:
  # { crate; source = "<Cargo.lock source string>"; hash = "<SRI of github archive
  # at the resolved rev>"; }. Workspace-member git deps (crate in a subdir) aren't
  # handled.
  gitDeps ? [ ],
  openssl ? false, # convenience: wire the pinned openssl (OPENSSL_NO_VENDOR + LIB/INCLUDE dirs) for openssl-sys / native-tls
  extraEnv ? { }, # extra build-time env vars reaching cargo/build.rs (RUSTC_BOOTSTRAP, a build.rs data path, a version override, ...)
  mainProgram ? builtins.head binaries,
  # Package metadata carried onto the bare derivation (like mkPackage).
  meta ? { },
  category ? null,
  updater ? null,
  hideFromDocs ? false, # build tools / helpers, not agent packages: skip the README + meta-completeness category
  system,
  pins,
  toolchains,
}:
let
  mkDrvSh = import ../drv-sh.nix;
  cargoVendor = import ../../vendor/cargo;
  sys = (import ../../seed/systems.nix).${system};
  inherit (toolchains) rust zig;

  gnuTarget = "${sys.zig.platform}-gnu"; # zig cc target
  rustGnu = sys.rust.gnu; # cargo [target.<triple>]

  fetchurl = import ../../fetch/fetchurl.nix;
  # Parse a git dep's Cargo.lock source string for the vendorer + config.toml.
  # source = "git+<url>[?rev=|?branch=|?tag=<v>]#<resolved-rev>".
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
  drv = mkDrvSh {
    inherit system;
    name = if version == null then "${pname}" else "${pname}-${version}";
    env = {
      inherit
        src
        vendor
        rust
        zig
        rustGnu
        gnuTarget
        ;
      inherit gitConfig; # [source."..."] git-dep replacement blocks
      installBins = builtins.concatStringsSep " " binaries;
      patchFiles = builtins.concatStringsSep " " patches;
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
    script = ./builder.sh;
  };
in
drv
// {
  # rust source builds are linux-only for now (the rust + zig toolchains
  # are Linux); callers can widen meta.platforms once aarch64 is verified.
  meta = {
    platforms = [ "x86_64-linux" ];
    inherit mainProgram;
  }
  // meta;
  passthru =
    (if category == null then { } else { inherit category; })
    // (if updater == null then { } else { inherit updater; })
    // (if hideFromDocs then { inherit hideFromDocs; } else { });
  # the produced binaries are patchelf'd to the pinned glibc/gccLib, so the FHS
  # check treats them like a kind = "patchelf" mkPackage output.
  fhs = {
    kind = "patchelf";
    inherit libpath mainProgram;
    ignoreMissing = "";
  };
}
// (if updater == null then { } else { inherit updater; })
