# dsh - built on corepkgs (nixpkgs-free) via mkNpm. Prebuilt registry tarball
# (dontNpmBuild); node_modules vendored from the committed lock. The bin needs
# node's --expose-internals flag, so we override the launcher (nixpkgs makeWrapper
# --add-flags equiv).
{
  mkNpm,
  coreFetchurl,
  flake,
}:
mkNpm {
  pname = "dsh";
  version = "0.1.0-rc.6";
  src = coreFetchurl {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-0.1.0-rc.6.tgz";
    hash = "sha256-G4qaCtPH/q7OR5JuC9N8oVHHzPqZeVOvpf0BJheE6tw=";
  };
  packageLock = ./package-lock.json;
  npmDepsHash = "sha256-ORD3lcEaxaSS8X92LKQ4TNucCZO04i4Aml+99wUiUvk=";
  buildScript = "";
  nativeAddons = true; # bundles a prebuilt node-addon-require-builtin .node addon
  binWrappers.dsh = {
    entry = "lib/bin.js";
    nodeFlags = [ "--expose-internals" ];
  };
  category = "AI Coding Agents";
  meta = {
    description = "Open-source agent harness developed by DeepSeek AI";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    changelog = "https://github.com/deepseek-ai/deepseek-harness/releases";
    license = flake.lib.licenses.mit;
    sourceProvenance = [
      flake.lib.sourceTypes.binaryBytecode
      flake.lib.sourceTypes.fromSource
    ];
    maintainers = with flake.lib.maintainers; [ JachinShen ];
  };
}
