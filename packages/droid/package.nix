# droid (Factory AI's CLI) - built on corepkgs, the repo's nixpkgs-free
# packaging system. droid is a bun --compile single-file binary that bundles its
# own ripgrep for code search.
#
# kind = "loader": a bun-compiled binary segfaults on any ELF rewrite (its
# appended JS payload), so leave it byte-intact and invoke the pinned glibc
# loader through the wrapper. rg is fetched separately and bundled onto PATH.
#
# NOTE: droid's ./hashes.json nests its hashes under `droid`/`ripgrep` per
# platform, a shape mkPackage's shared-hashes reader cannot consume, so the
# source is pinned inline (single-platform, mirroring the current hashes.json).
{
  mkPackage,
  coreFetchurl,
  flake,
}:
mkPackage {
  pname = "droid";
  version = "0.196.0";
  src = coreFetchurl {
    url = "https://downloads.factory.ai/factory-cli/releases/0.196.0/linux/x64/droid";
    hash = "sha256-4Gof9XPv3B2PLDrqdAhX0hzX/ylEIJ9q594VX7v2zfw=";
  };
  unpack = "none";
  kind = "loader";
  runtimeBins = [
    {
      name = "rg";
      src = coreFetchurl {
        url = "https://downloads.factory.ai/ripgrep/linux/x64/rg";
        hash = "sha256-viR2yXY0K5IWYRtKhMG8LsZIjsXHkeoBmhMnJ2RO8Zw=";
      };
    }
  ];

  category = "AI Coding Agents";

  meta = {
    description = "Factory AI's Droid - AI-powered development agent for your terminal";
    # Inline-pinned x86_64 binary only (mkPackage cannot yet read this
    # package's nested per-platform hashes.json); gate accordingly.
    platforms = [ "x86_64-linux" ];
    homepage = "https://factory.ai";
    changelog = "https://docs.factory.ai/changelog/cli-updates";
    downloadPage = "https://factory.ai/product/ide";
    license = flake.lib.licenses.unfree;
    sourceProvenance = [ flake.lib.sourceTypes.binaryNativeCode ];
    maintainers = [ ];
  };
}
