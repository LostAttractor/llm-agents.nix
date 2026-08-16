# ccusage - built from source on corepkgs (nixpkgs-free) via mkCargo. Rust
# workspace at rust/ (-p ccusage). build.rs embeds a LiteLLM pricing snapshot; a
# build-time download is forbidden in the sandbox, so pass a pinned copy via
# CCUSAGE_PRICING_JSON_PATH (the litellm rev must match the tag's flake.lock).
{
  mkCargo,
  coreFetchurl,
  flake,
}:
let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);
  # litellm rev pinned by the tag's flake.lock (nodes.litellm.locked.rev).
  litellm-pricing = coreFetchurl {
    url = "https://raw.githubusercontent.com/BerriAI/litellm/34561482ed092d78c296cab7999486022af5a938/model_prices_and_context_window.json";
    hash = "sha256-jV/bRDNx+DNMKMsP9kvw82rRNexvdm7sdnzGLTt/gJI=";
  };
in
mkCargo {
  pname = "ccusage";
  inherit (data) version;
  src = coreFetchurl {
    url = "https://github.com/ccusage/ccusage/archive/refs/tags/v${data.version}.tar.gz";
    inherit (data) hash;
  };
  sourceRoot = "rust";
  cargoLock = ./Cargo.lock;
  binaries = [ "ccusage" ];
  cargoBuildFlags = [
    "-p"
    "ccusage"
    "--bin"
    "ccusage"
  ];
  extraEnv = {
    CCUSAGE_PRICING_JSON_PATH = "${litellm-pricing}";
    CCUSAGE_VERSION = data.version;
  };

  category = "Usage Analytics";
  meta = {
    description = "Analyze coding agent CLI token usage and costs from local data";
    homepage = "https://ccusage.com/";
    changelog = "https://github.com/ccusage/ccusage/releases/tag/v${data.version}";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.ryoppippi ];
  };
}
