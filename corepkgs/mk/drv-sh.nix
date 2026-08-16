# mkDrvSh: a derivation whose builder is the sandbox /bin/sh + busybox, script in
# POSIX sh. The workhorse for shell-glue builds - the vendorers and every source
# constructor (cargo/go/npm/bun/pnpm/python) run build tools with plain env vars +
# loops, natural in sh. (mkDrvNu, nushell, is for data-processing builds like
# check-fhs.) Boots busybox applets onto PATH via `exec -a busybox`.
{
  name,
  script,
  env ? { },
  system,
}:
let
  fetchurl = import ../fetch/fetchurl.nix;
  isDarwin = builtins.match ".*-darwin" system != null;
  # Linux bundles a static busybox; Darwin has none, so use the sandbox's system
  # tools (/usr/bin/tar, /bin/chmod) like nixpkgs' darwin stdenv.
  busybox =
    if isDarwin then
      null
    else
      fetchurl {
        inherit ((import ../seed/systems.nix).${system}.busybox) url hash;
        executable = true;
      };
  prelude =
    if isDarwin then
      ''
        set -eu
        export PATH="/usr/bin:/bin"
      ''
    else
      ''
        set -eu
        __bb() { ( exec -a busybox "@busybox@" "$@" ); }
        __seedbin="$NIX_BUILD_TOP/.seed-bin"
        __bb mkdir -p "$__seedbin"
        __bb --install -s "$__seedbin"
        export PATH="$__seedbin''${PATH:+:$PATH}"
      '';
in
derivation (
  env
  // {
    inherit name system;
    builder = "/bin/sh";
    args = [
      "-c"
      (builtins.replaceStrings [ "@busybox@" ] [ (if isDarwin then "" else "${busybox}") ] (
        prelude + "\n" + script
      ))
    ];
  }
)
