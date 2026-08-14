# The bootstrap seed for a given system, zero nixpkgs:
#   busybox - truly-static; provides archive extraction (tar/unzip/xz) that
#             nushell has no built-in for.
#   nu      - nushell (truly-static musl), the real build-script runtime. It is
#             extracted from its tarball by the tiny sh bootstrap (mk-naked-sh),
#             since nushell ships as a .tar.gz and nothing else can extract it
#             before nu exists.
{
  system,
}:
let
  fetchurl = import ./fetchurl.nix;
  mkNakedSh = import ./mk-naked-sh.nix;
  sys = (import ./systems.nix).${system};

  busybox = fetchurl {
    inherit (sys.busybox) url hash;
    executable = true;
  };
  nuTar = fetchurl { inherit (sys.nu) url hash; };
  nushell = mkNakedSh {
    inherit system;
    name = "nushell";
    env = { inherit nuTar; };
    script = ''
      mkdir -p "$out/bin"
      tar -xzf "$nuTar"
      cp "${sys.nu.dir}/nu" "$out/bin/nu"
      chmod 0755 "$out/bin/nu"
    '';
  };
in
{
  inherit busybox;
  nu = "${nushell}/bin/nu";
}
