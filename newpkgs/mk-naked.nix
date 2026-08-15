# mkNaked: build a derivation with no nixpkgs and no stdenv, for a given system.
# The builder is a truly-static nushell; __structuredAttrs exposes the
# derivation attrs (params + outputs) as JSON, which nushell `open`s natively -
# so params pass as real lists/records, not string-munged env vars, and the
# scripts are structured nushell (no POSIX-sh footguns, no busybox argv[0] hack).
#
# The prelude puts busybox's archive tools (tar/unzip/xz - nushell has no
# built-in extraction) on PATH, and binds `$attrs` = the JSON attrs.
{
  name,
  script,
  env ? { },
  system,
}:
let
  seed = import ./seed.nix { inherit system; };
  prelude = ''
    let attrs = (open $env.NIX_ATTRS_JSON_FILE)
    let out = $attrs.outputs.out
    # busybox archive tools: it dispatches on argv[0], so copy it to a
    # "busybox"-named path, --install its applets, and put them on PATH.
    let bbdir = $"($env.NIX_BUILD_TOP)/.bb"
    mkdir $bbdir
    cp @busybox@ $"($bbdir)/busybox"
    ^$"($bbdir)/busybox" --install -s $bbdir
    $env.PATH = ($env.PATH | prepend $bbdir)
  '';
in
derivation (
  env
  // {
    inherit name system;
    __structuredAttrs = true;
    builder = seed.nu;
    args = [
      "--no-config-file"
      "--commands"
      (builtins.replaceStrings [ "@busybox@" ] [ "${seed.busybox}" ] (prelude + "\n" + script))
    ];
  }
)
