# qoder-cli (Qoder's `qodercli` AI coding assistant) - built on corepkgs, the
# repo's nixpkgs-free packaging system. `mkPackage` fetches the prebuilt release
# tarball and wraps it.
#
# qodercli is a bun --compile single-file binary, so kind = "loader" leaves it
# byte-intact and invokes the pinned glibc loader through the wrapper.
#
# NOTE: qoder's ./hashes.json nests each platform's url+hash under `platforms`,
# a shape mkPackage's shared-hashes reader cannot consume, so the source is
# pinned inline (single-platform, mirroring the current hashes.json). The
# declarative updater below still tracks all upstream platforms.
{
  mkPackage,
  mkUpdater,
  coreFetchurl,
  flake,
}:
mkPackage {
  pname = "qoder-cli";
  version = "1.1.22";
  mainProgram = "qodercli";
  src = coreFetchurl {
    url = "https://qoder-ide.oss-accelerate.aliyuncs.com/qodercli/releases/1.1.22/qodercli-linux-x64.tar.gz";
    hash = "sha256-nrlsdKG9E4v82F6Yyz9KP5/EUQ/tMotrE/JZDnQZ5LE=";
  };
  unpack = "tar";
  binary = "qodercli";
  kind = "loader";
  # Disable self-update: the store binary is read-only, so an in-place update
  # attempt would just fail.
  setEnv = {
    QODER_DISABLE_AUTO_UPDATE = "1";
  };

  category = "AI Coding Agents";
  updater = mkUpdater {
    kind = "manifest";
    manifestUrl = "https://qoder-ide.oss-ap-southeast-1.aliyuncs.com/qodercli/channels/manifest.json";
    platformMap = [
      {
        os = "linux";
        arch = "amd64";
        platform = "x86_64-linux";
      }
      {
        os = "linux";
        arch = "arm64";
        platform = "aarch64-linux";
      }
      {
        os = "darwin";
        arch = "arm64";
        platform = "aarch64-darwin";
      }
    ];
  };

  meta = {
    description = "Qoder AI CLI tool - Terminal-based AI assistant for code development";
    # Inline-pinned x86_64 binary only (mkPackage cannot yet read this
    # package's nested per-platform hashes.json); gate accordingly.
    platforms = [ "x86_64-linux" ];
    homepage = "https://qoder.com";
    changelog = "https://qoder.com/changelog";
    downloadPage = "https://qoder.com/download";
    license = flake.lib.licenses.unfree;
    sourceProvenance = [ flake.lib.sourceTypes.binaryNativeCode ];
    maintainers = [ ];
  };
}
