# cubic — bun-compiled binary in a zip. Ported onto the naked base.
{
  system,
  pins,
}:
let
  mkBinary = import ../mk/binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "cubic";
  hashesFile = ../../packages/cubic/hashes.json;
  urlTemplate = "https://mcafvrhahbqdwfrtncql.supabase.co/storage/v1/object/public/releases/v{version}/cubic-linux-x64.zip";
  unpack = "zip";
  binary = "cubic";
  kind = "loader";
}
