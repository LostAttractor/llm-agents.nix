# qoder-cli-cn (Qoder CLI, mainland China edition) - built on corepkgs, the
# repo's nixpkgs-free packaging system. Same bun-compiled binary as qoder-cli,
# but the mainland-China service: separate release channel/CDN, binary name
# (qoderclicn) and account backend.
#
# qoderclicn is a bun --compile single-file binary, so kind = "loader" leaves
# it byte-intact and invokes the pinned glibc loader through the wrapper.
#
# NOTE: like qoder-cli, ./hashes.json nests each platform's url+hash under
# `platforms`, a shape mkBinary's shared-hashes reader cannot consume, so the
# source is pinned inline (single-platform, mirroring the current hashes.json).
# The declarative updater below still tracks all upstream platforms.
{
  mkBinary,
  mkUpdater,
  coreFetchurl,
  flake,
}:
mkBinary {
  pname = "qoder-cli-cn";
  version = "1.1.22";
  mainProgram = "qoderclicn";
  src = coreFetchurl {
    url = "https://static.qoder.com.cn/qoder-cli-cn/releases/1.1.22/qoderclicn-linux-x64.tar.gz";
    hash = "sha256-9/j02TbkR0o2bv/z2eUyd78b/urYE39JWlQieq5rYaQ=";
  };
  unpack = "tar";
  binary = "qoderclicn";
  kind = "loader";
  # Disable self-update: the store binary is read-only, so an in-place update
  # attempt would just fail.
  setEnv = {
    QODER_DISABLE_AUTO_UPDATE = "1";
  };

  category = "AI Coding Agents";
  updater = mkUpdater {
    kind = "manifest";
    manifestUrl = "https://static.qoder.com.cn/qoder-cli-cn/channels/manifest.json";
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
    description = "Qoder CLI (mainland China edition) - terminal-based AI coding assistant for China-region accounts";
    homepage = "https://qoder.cn";
    changelog = "https://qoder.cn/changelog";
    downloadPage = "https://qoder.cn/download";
    license = flake.lib.licenses.unfree;
    sourceProvenance = [ flake.lib.sourceTypes.binaryNativeCode ];
    maintainers = with flake.lib.maintainers; [ RyougiShiki-214 ];
  };
}
