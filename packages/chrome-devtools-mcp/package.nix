{
  lib,
  flake,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
  versionCheckHook,
  versionCheckHomeHook,
}:

buildNpmPackage rec {
  pname = "chrome-devtools-mcp";
  version = "1.5.0";

  src = fetchFromGitHub {
    owner = "ChromeDevTools";
    repo = "chrome-devtools-mcp";
    tag = "chrome-devtools-mcp-v${version}";
    hash = "sha256-qDji1ZA46H3+jEZ5SL7ga/pyRhJ9SAdBWYH1jKC/TVg=";
  };

  inherit nodejs;

  npmDepsHash = "sha256-t9PwLvjcUaGFBZpW504+V96TbEVukOp3skomtTFs8cA=";

  # puppeteer is a build-time dependency that upstream bundles into the
  # server via rollup; its postinstall would otherwise download a Chrome
  # binary the Nix sandbox cannot fetch. chrome-devtools-mcp does not ship a
  # browser: point it at one with `--executablePath`, `--channel`, or
  # `--browser-url` at runtime.
  env.PUPPETEER_SKIP_DOWNLOAD = "true";

  # buildNpmPackage installs with `--ignore-scripts`, so the root `prepare`
  # script does not run automatically. It patches a conflicting global type
  # declaration in a dependency that otherwise breaks the `tsc` build.
  preBuild = ''
    npm run prepare
  '';

  # `bundle` runs tsc + rollup to produce the self-contained build/ output
  # with all runtime dependencies vendored into build/src/third_party.
  npmBuildScript = "bundle";

  nativeBuildInputs = [ makeWrapper ];

  # Opt out of upstream's telemetry by default: usage statistics sent to
  # Google and performance-trace URLs sent to the CrUX API. Both flags stay
  # overridable (yargs is last-wins), e.g. `--usage-statistics` re-enables it.
  # Only the chrome-devtools-mcp server accepts these; the chrome-devtools
  # CLI does not, so it is left unwrapped.
  postInstall = ''
    wrapProgram $out/bin/chrome-devtools-mcp \
      --add-flags "--no-usage-statistics --no-performance-crux"
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Utilities";

  meta = with lib; {
    description = "MCP server that lets coding agents debug web pages in a live Chrome browser via Chrome DevTools";
    homepage = "https://github.com/ChromeDevTools/chrome-devtools-mcp";
    changelog = "https://github.com/ChromeDevTools/chrome-devtools-mcp/releases/tag/chrome-devtools-mcp-v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ aldoborrero ];
    mainProgram = "chrome-devtools-mcp";
    platforms = platforms.all;
  };
}
