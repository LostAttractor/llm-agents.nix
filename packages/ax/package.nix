# ax - built from source on corepkgs (nixpkgs-free) via mkBun. Pure-JS bun CLI;
# mkBun installs the app + vendored node_modules under $out/lib/ax and wraps
# `bun run src/index.ts` on the naked bun toolchain (no --compile needed).
{
  mkBun,
  coreFetchurl,
  flake,
}:
mkBun {
  pname = "ax";
  version = "0.1.25";
  src = coreFetchurl {
    url = "https://github.com/yusukebe/ax/archive/refs/tags/v0.1.25.tar.gz";
    hash = "sha256-txjmFzSNIyt8cqQNVdfVTBc0+6o5LQmpKjXaJA9PX28=";
  };
  bunDepsHash = "sha256-j5HCMOHtjZpo0ngCWxERm9IFMT7r6NmEsr5KX2jEIeg=";
  entry = "src/index.ts";

  category = "Utilities";
  meta = {
    description = "The AI-era curl: fetch, discover, extract. One command";
    homepage = "https://github.com/yusukebe/ax";
    changelog = "https://github.com/yusukebe/ax/releases/tag/v0.1.25";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.ryoppippi ];
  };
}
