# Vendor a Cargo.lock's crates.io dependencies as naked FODs and assemble a
# cargo vendor directory - the nixpkgs-free equivalent of fetchCargoVendor.
# Each .crate is fetched by builtin:fetchurl using the sha256 straight from
# Cargo.lock; the vendor dir gets a .cargo-checksum.json per crate.
let
  mkNaked = import ./mk/naked-sh.nix;

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
in
mkNaked {
  inherit system;
  name = "cargo-vendor";
  env = { inherit manifest; };
  script = ''
    mkdir -p "$out"
    printf '%s\n' "$manifest" | while read -r name version sha crate; do
      [ -n "$name" ] || continue
      # each .crate untars to $out/<name>-<version>/
      tar -xzf "$crate" -C "$out"
      printf '{"files":{},"package":"%s"}' "$sha" > "$out/$name-$version/.cargo-checksum.json"
    done
  '';
}
