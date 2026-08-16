# Vendor a Cargo.lock's crates.io deps: each .crate is one builtin:fetchurl FOD
# keyed by the sha256 straight from Cargo.lock. Assemble the cargo vendor dir
# with a .cargo-checksum.json per crate.
let
  mkDrvSh = import ../mk/drv-sh.nix;

  fetchCrate =
    {
      name,
      version,
      sha256hex,
    }:
    let
      url = "https://static.crates.io/crates/${name}/${name}-${version}.crate";
    in
    derivation {
      inherit url;
      name = "${name}-${version}.crate";
      builder = "builtin:fetchurl";
      system = "builtin";
      urls = [ url ];
      outputHashAlgo = "sha256";
      outputHashMode = "flat";
      outputHash = sha256hex; # hex, straight from Cargo.lock
      unpack = false;
      executable = false;
      preferLocalBuild = true;
    };
in
{
  cargoLock,
  system,
  # git deps: [{ crate = "<name>"; archive = <fetched github archive tarball>; }].
  # cargo vendors a git dep under a plain <crate>/ dir with a null-package
  # checksum; source-replacement wiring lives in mk/cargo.nix's config.toml.
  gitDeps ? [ ],
}:
let
  lock = builtins.fromTOML (builtins.readFile cargoLock);
  crates = builtins.filter (p: p ? checksum) lock.package;
  line =
    p:
    "${p.name} ${p.version} ${p.checksum} ${
      fetchCrate {
        inherit (p) name version;
        sha256hex = p.checksum;
      }
    }";
  manifest = builtins.concatStringsSep "\n" (map line crates);
  gitManifest = builtins.concatStringsSep "\n" (map (g: "${g.crate} ${g.archive}") gitDeps);
in
mkDrvSh {
  inherit system;
  name = "cargo-vendor";
  env = { inherit manifest gitManifest; };
  script = ''
    mkdir -p "$out"
    printf '%s\n' "$manifest" | while read -r name version sha crate; do
      [ -n "$name" ] || continue
      # each .crate untars to $out/<name>-<version>/
      tar -xzf "$crate" -C "$out"
      printf '{"files":{},"package":"%s"}' "$sha" > "$out/$name-$version/.cargo-checksum.json"
    done
    # git deps: the archive untars to a single <repo>-<rev>/ top dir; move it to
    # $out/<crate>/ and give it the git-source null-package checksum.
    printf '%s\n' "$gitManifest" | while read -r crate archive; do
      [ -n "$crate" ] || continue
      rm -rf "$NIX_BUILD_TOP/gx" && mkdir -p "$NIX_BUILD_TOP/gx"
      tar -xzf "$archive" -C "$NIX_BUILD_TOP/gx"
      mv "$NIX_BUILD_TOP/gx"/* "$out/$crate"
      printf '{"files":{},"package":null}' > "$out/$crate/.cargo-checksum.json"
    done
  '';
}
