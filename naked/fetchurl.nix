# Naked builtin:fetchurl — a lone leaf derivation. No nixpkgs, no stdenv.
# `executable` fetches a runnable binary (NAR/recursive hash, +x bit);
# otherwise a flat file.
{
  url,
  hash,
  executable ? false,
}:
derivation {
  inherit url executable;
  name = baseNameOf url;
  builder = "builtin:fetchurl";
  system = "builtin";
  urls = [ url ];
  outputHash = hash;
  outputHashMode = if executable then "recursive" else "flat";
  outputHashAlgo = null;
  unpack = false;
  preferLocalBuild = true;
}
