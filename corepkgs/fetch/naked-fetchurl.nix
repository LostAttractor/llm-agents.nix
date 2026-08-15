# fetchurl on the builtin:fetchurl builder: a lone leaf derivation, no nixpkgs
# fetchurl wrapper or stdenv thunk graph. Same output path as pkgs.fetchurl
# for a given url + hash.
#
# Args are closed on purpose (url, hash, executable) - the builtin serves
# nothing else (no unpack, auth, or curl opts), so anything extra fails loudly
# instead of being silently dropped. bun2nix passes only { url, hash } (the
# executable default is a no-op there); the naked build layer also fetches
# runnable binaries with `executable = true` (recursive/NAR hash + the +x bit).
{
  url,
  hash,
  executable ? false,
  name ? baseNameOf url, # override when the URL basename isn't a legal store name
}:
derivation {
  inherit url executable name;
  builder = "builtin:fetchurl";
  system = "builtin";
  urls = [ url ];
  outputHash = hash;
  outputHashMode = if executable then "recursive" else "flat";
  outputHashAlgo = null;
  preferLocalBuild = true;
  unpack = false;
}
