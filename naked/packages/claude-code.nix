# claude-code (Anthropic) - bun-compiled single-file binary. Runtime deps:
# bubblewrap + socat (sandboxing); disables auto-update/telemetry via env.
{
  system,
  pins,
}:
let
  fetchurl = import ../fetchurl.nix;
  mkBinary = import ../mk-binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "claude-code";
  version = "2.1.232";
  mainProgram = "claude";
  src = fetchurl {
    url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/2.1.232/linux-x64/claude";
    hash = "sha256-YdI/h0kTaQfVhtWxGDHqilI01MHepApeVcM7UuIExtE=";
  };
  unpack = "none";
  kind = "loader";
  runtimePkgs = [
    pins.bubblewrap
    pins.socat
  ];
  setEnv = {
    DISABLE_AUTOUPDATER = "1";
    DISABLE_INSTALLATION_CHECKS = "1";
    DISABLE_NON_ESSENTIAL_MODEL_CALLS = "1";
  };
}
