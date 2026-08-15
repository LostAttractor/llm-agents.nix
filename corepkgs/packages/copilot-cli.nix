# copilot-cli (GitHub Copilot CLI) - the @github/copilot npm loader ships a
# per-platform Node single-executable application (SEA): the `copilot` binary
# with an appended payload, plus bundled ripgrep/tgrep and many native .node
# modules. formatelf cannot rewrite the SEA's headers (the appended blob makes
# it "truncated"), and any ELF edit corrupts it - so leave it byte-intact and
# invoke the pinned loader through the wrapper (kind = "loader"). dir-install
# the whole tree so the SEA finds its bundled rg/tgrep and native modules.
# The bundled webview module needs GTK/webkit/wayland libs the CLI never loads;
# allow them to stay unresolved (like nixpkgs autoPatchelfIgnoreMissingDeps).
{ system, pins }:
let
  mkBinary = import ../mk/binary.nix;
in
mkBinary {
  inherit system pins;
  pname = "copilot-cli";
  hashesFile = ../../packages/copilot-cli/hashes.json;
  urlTemplate = "https://registry.npmjs.org/@github/copilot-linux-x64/-/copilot-linux-x64-{version}.tgz";
  unpack = "tar";
  installDir = "package";
  entrypoint = "copilot";
  mainProgram = "copilot";
  kind = "loader";
  libs = [ pins.zlib ];
  setEnv = {
    COPILOT_AUTO_UPDATE = "false";
  };
  ignoreMissing = [
    "libwebkit2gtk-4.1.so.0"
    "libgtk-3.so.0"
    "libgdk-3.so.0"
    "libcairo.so.2"
    "libgdk_pixbuf-2.0.so.0"
    "libsoup-3.0.so.0"
    "libgio-2.0.so.0"
    "libjavascriptcoregtk-4.1.so.0"
    "libgobject-2.0.so.0"
    "libglib-2.0.so.0"
    "libwayland-client.so.0"
    "libdbus-1.so.3"
    "libxdo.so.3"
  ];
}
