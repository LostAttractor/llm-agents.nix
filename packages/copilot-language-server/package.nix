# copilot-language-server - built on corepkgs (nixpkgs-free) via mkNpm. Prebuilt
# registry tarball (dontNpmBuild); node_modules vendored from the committed lock.
# The upstream package.json bin escapes the package dir, so we override the
# launcher to point node at the real dist entrypoint (nixpkgs makeWrapper equiv).
{
  mkNpm,
  coreFetchurl,
  flake,
}:
mkNpm {
  pname = "copilot-language-server";
  version = "1.532.0";
  src = coreFetchurl {
    url = "https://registry.npmjs.org/@github/copilot-language-server/-/copilot-language-server-1.532.0.tgz";
    hash = "sha256-54AkqlAKHdmNxU3oh5aFiDNCbI8e9cemZEzsZUiPmWI=";
  };
  packageLock = ./package-lock.json;
  npmDepsHash = "sha256-a70kHH/Nvh9kB+kDvlcn2LfSEiVeY/ehHkadP6M5QUA=";
  buildScript = "";
  # upstream ships optional cross-platform clipboard/webview prebuilds it does
  # not need (nixpkgs drops them the same way); omit them to stay store-only.
  omitOptional = true;
  binWrappers.copilot-language-server.entry = "dist/language-server.js";
  category = "Utilities";
  meta = {
    description = "GitHub Copilot Language Server - AI pair programmer LSP";
    homepage = "https://github.com/github/copilot-language-server-release";
    changelog = "https://github.com/github/copilot-language-server-release/releases/tag/1.532.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.binaryBytecode ];
    maintainers = [ ];
  };
}
