# cubic — bun-compiled binary in a zip. Ported onto the naked base.
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  pname = "cubic";
  version = "1.10.4";
  src = fetchurl {
    url = "https://mcafvrhahbqdwfrtncql.supabase.co/storage/v1/object/public/releases/v1.10.4/cubic-linux-x64.zip";
    hash = "sha256-MdP5Hqb1j7zQe5+rIgRgoQ//EnjJxwS03uJW40VdgWs=";
  };
  unpack = "zip";
  binary = "cubic";
  kind = "loader";
}
