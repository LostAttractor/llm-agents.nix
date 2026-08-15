# mkNakedSh: the POSIX-sh bootstrap builder (sandbox /bin/sh + busybox). Used
# only to extract nushell from its tarball; the real build logic uses mk-naked.nix
# (nushell + __structuredAttrs). Kept minimal.
# The builder is the sandbox's /bin/sh (Nix guarantees it); it boots busybox's
# applets into PATH via `exec -a busybox` (busybox dispatches on argv[0], which
# Nix hash-prefixes) then runs the build script. ~10 lines vs stdenv's ~2000.
{
  name,
  script,
  env ? { },
  system,
}:
let
  fetchurl = import ../fetchurl.nix;
  isDarwin = builtins.match ".*-darwin" system != null;
  # Linux: bundle a truly-static busybox and boot its applets onto PATH.
  # Darwin: macOS ships no static busybox; the sandbox exposes the system
  # toolchain (/usr/bin/tar, /bin/chmod), same as nixpkgs' darwin stdenv.
  busybox =
    if isDarwin then
      null
    else
      fetchurl {
        inherit ((import ../systems.nix).${system}.busybox) url hash;
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
