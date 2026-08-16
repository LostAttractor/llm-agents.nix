# ralph-tui - built from source on corepkgs (nixpkgs-free) via mkBun. The upstream
# `bun run build` bundles src/cli.tsx -> dist/cli.js (externalizing @opentui/* and
# react, which stay in the vendored node_modules) and copies assets/skills/templates.
# mkBun then wraps `bun run dist/cli.js` on the naked bun toolchain (no --compile,
# which @opentui/core's top-level-await FFI could not use anyway).
{
  mkBun,
  coreFetchurl,
  flake,
}:
mkBun {
  pname = "ralph-tui";
  version = "0.12.0";
  src = coreFetchurl {
    url = "https://github.com/subsy/ralph-tui/archive/refs/tags/v0.12.0.tar.gz";
    hash = "sha256-KsyIEvZaal/e3hxG9zZxQ1r7rd3IO84Ka1LtCgoRvZo=";
  };
  bunDepsHash = "sha256-eRfGuZKCAkmDVpreHi7vmBPFHBlKCoPTeYwVX5eC3x4=";
  buildScript = "run build";
  entry = "dist/cli.js";

  category = "Workflow & Project Management";
  meta = {
    description = "AI Agent Loop Orchestrator TUI";
    homepage = "https://github.com/subsy/ralph-tui";
    changelog = "https://github.com/subsy/ralph-tui/releases/tag/v0.12.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ flake.lib.maintainers.afterthought ];
  };
}
