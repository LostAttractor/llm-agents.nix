# chrome-devtools-mcp

An [MCP](https://modelcontextprotocol.io) server that gives coding agents a
live Chrome browser to drive through the Chrome DevTools Protocol: navigate
pages, click and fill elements, capture screenshots, read the console and
network, and run performance traces.

This package builds the server from source with all of its runtime
dependencies (Puppeteer, Lighthouse, the DevTools frontend) bundled in, so it
runs on NixOS without pulling anything at runtime.

## Providing a browser

The package **does not bundle a browser**. Upstream defaults to launching the
stable Chrome it discovers at well-known filesystem paths
(`/opt/google/chrome`, `/usr/bin/google-chrome`, ...), none of which exist on
NixOS, so the default `--channel stable` fails to find a browser here.

Point it at a Nix-provided browser instead. Any of these work:

- **Explicit executable** — pass a Chromium/Chrome binary directly:

  ```bash
  nix run github:numtide/llm-agents.nix#chrome-devtools-mcp -- \
    --executablePath "$(command -v chromium)"
  ```

- **Running instance** — start Chrome yourself with remote debugging enabled
  and connect over the DevTools endpoint:

  ```bash
  chromium --remote-debugging-port=9222 &
  nix run github:numtide/llm-agents.nix#chrome-devtools-mcp -- \
    --browserUrl http://127.0.0.1:9222
  ```

Add `chromium` (or `google-chrome`) to your own configuration so the binary is
available; this package intentionally leaves that choice to you.

## Telemetry

This package disables upstream's telemetry by default — it wraps the server
with `--no-usage-statistics` (usage data sent to Google) and
`--no-performance-crux` (performance-trace URLs sent to the CrUX API). Both
stay overridable: pass `--usage-statistics` or `--performance-crux` to
re-enable them.

## MCP client configuration

Configure your agent to launch the server over stdio, supplying the browser
path. For example:

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "chrome-devtools-mcp",
      "args": ["--executablePath", "/run/current-system/sw/bin/chromium"]
    }
  }
}
```

## Try without installing

```bash
nix run github:numtide/llm-agents.nix#chrome-devtools-mcp -- --help
```

## Links

- [chrome-devtools-mcp GitHub repository](https://github.com/ChromeDevTools/chrome-devtools-mcp)
- [Available tools reference](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/tool-reference.md)
- [Model Context Protocol](https://modelcontextprotocol.io)
