{
  lib,
  flake,
  stdenv,
  stdenvNoCC,
  buildGoModule,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  fetchurl,
  nodejs_24,
  codex,
  codex-acp,
  gemini-cli,
  makeWrapper,
  rcodesign,
  git,
  bash,
  openssh,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  pname = "kandev";
  version = "0.88.0";

  src = fetchFromGitHub {
    owner = "kdlbs";
    repo = "kandev";
    tag = "v${version}";
    hash = "sha256-YLJ6shH/CCh7I8412Fw6tVuma4bCiBFheH9BDM49T1k=";
  };

  pnpm = pnpm_10.overrideAttrs (_: {
    version = "9.15.9";
    src = fetchurl {
      url = "https://registry.npmjs.org/pnpm/-/pnpm-9.15.9.tgz";
      hash = "sha256-z4anrXZEBjldQoam0J1zBxFyCsxtk+nc6ax6xNxKKKc=";
    };
  });

  frontend = stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "kandev-web";
    inherit version src;

    sourceRoot = "${src.name}/apps";

    pnpmDeps = fetchPnpmDeps {
      inherit (finalAttrs)
        pname
        version
        src
        sourceRoot
        ;
      inherit pnpm;
      fetcherVersion = 4;
      hash = "sha256-5GBYP7Ryr7RkIzxTsc15y1squza74KwgyS39rtfJPq0=";
    };

    nativeBuildInputs = [
      nodejs_24
      pnpm
      pnpmConfigHook
    ];

    buildPhase = ''
      runHook preBuild
      KANDEV_VERSION=${version} VITE_KANDEV_API_PORT= VITE_KANDEV_DEBUG= \
        pnpm --filter @kandev/web build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -r web/dist $out
      runHook postInstall
    '';
  });
in
buildGoModule (_finalAttrs: {
  inherit pname version src;

  modRoot = "apps/backend";
  vendorHash = "sha256-68fOqzojvBNAFL6MDw7G8NpLf1PBgAjwJipQcWdple8=";

  subPackages = [
    "cmd/kandev"
    "cmd/agentctl"
  ];

  tags = [ "fts5" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=v${version}"
  ];

  postPatch = ''
    substituteInPlace apps/backend/internal/agent/agents/codex_acp.go \
      --replace-fail 'a.ManagedNPMRuntime().CachedACPCommand()' 'NewCommand("codex-acp")' \
      --replace-fail 'NewCommand("npx", "-y", "@openai/codex")' 'NewCommand("codex")'
    substituteInPlace apps/backend/internal/agent/agents/gemini.go \
      --replace-fail 'a.ManagedNPMRuntime().CachedACPCommand()' 'NewCommand("gemini", "--acp")' \
      --replace-fail 'NewCommand("npx", "--yes", "--prefer-offline", geminiPackage)' 'NewCommand("gemini")'
    old_probe_command='"npx":           "npx",'
    new_probe_commands=$'"codex-acp":     "codex-acp",\n\t"gemini":        "gemini",\n\t"npx":           "npx",'
    substituteInPlace apps/backend/internal/agentctl/server/utility/acp_executor.go \
      --replace-fail "$old_probe_command" "$new_probe_commands"
  '';

  preBuild = ''
    generated=internal/webapp/embedded/generated
    find "$generated" -mindepth 1 ! -name .gitignore ! -name keep.txt -exec rm -rf {} +
    cp -r ${frontend}/. "$generated/"
  '';

  postBuild = ''
    helper_ldflags="-s -w"
    env CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
      go build -ldflags "$helper_ldflags" -o agentctl-linux-amd64 ./cmd/agentctl
    env CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
      go build -ldflags "$helper_ldflags" -o agentctl-linux-arm64 ./cmd/agentctl
    env CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 \
      go build -ldflags "$helper_ldflags" -o agentctl-darwin-arm64 ./cmd/agentctl
    env CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 \
      go build -ldflags "$helper_ldflags" -o agentctl-darwin-amd64 ./cmd/agentctl
  '';

  nativeBuildInputs = [
    makeWrapper
    rcodesign
  ];

  postInstall = ''
    mkdir -p $out/libexec/kandev/bin
    mv $out/bin/kandev $out/bin/agentctl $out/libexec/kandev/bin/
    install -Dm755 agentctl-linux-amd64 $out/libexec/kandev/bin/agentctl-linux-amd64
    install -Dm755 agentctl-linux-arm64 $out/libexec/kandev/bin/agentctl-linux-arm64
    install -Dm755 agentctl-darwin-arm64 $out/libexec/kandev/bin/agentctl-darwin-arm64
    install -Dm755 agentctl-darwin-amd64 $out/libexec/kandev/bin/agentctl-darwin-amd64

    makeWrapper $out/libexec/kandev/bin/kandev $out/bin/kandev \
      --set KANDEV_BUNDLE_DIR $out/libexec/kandev \
      --set KANDEV_VERSION ${version} \
      --prefix PATH : ${
        lib.makeBinPath [
          nodejs_24
          codex
          codex-acp
          gemini-cli
          git
          bash
          openssh
        ]
      }
  '';

  # Do not let fixup mutate the cross-platform helpers. Re-sign every Darwin
  # binary after fixup because Mach-O mutations invalidate ad-hoc signatures.
  dontStrip = true;

  postFixup = ''
    ${lib.getExe rcodesign} sign --code-signature-flags linker-signed \
      $out/libexec/kandev/bin/agentctl-darwin-arm64
    ${lib.getExe rcodesign} sign --code-signature-flags linker-signed \
      $out/libexec/kandev/bin/agentctl-darwin-amd64
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    ${lib.getExe rcodesign} sign --code-signature-flags linker-signed \
      $out/libexec/kandev/bin/kandev
    ${lib.getExe rcodesign} sign --code-signature-flags linker-signed \
      $out/libexec/kandev/bin/agentctl
  '';

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
    nodejs_24
  ];
  versionCheckProgramArg = "--version";

  postInstallCheck = ''
    $out/bin/kandev --help >/dev/null
    grep -aF '${nodejs_24}/bin' $out/bin/kandev >/dev/null

    set +e
    output="$($out/libexec/kandev/bin/agentctl kandev 2>&1)"
    status=$?
    set -e
    test "$status" -eq 1
    grep -F "Usage: agentctl kandev" <<<"$output"

    helpers="agentctl-linux-amd64 agentctl-linux-arm64 agentctl-darwin-arm64 agentctl-darwin-amd64"
    for helper in $helpers; do
      test -x "$out/libexec/kandev/bin/$helper"
    done

    node ${src}/scripts/release/validate-darwin-arm64-helper.mjs \
      $out/libexec/kandev/bin/agentctl-darwin-arm64
  '';

  passthru = {
    category = "Workflow & Project Management";
    inherit frontend;
  };

  meta = {
    description = "Manage tasks, orchestrate agents, review changes, and ship value";
    homepage = "https://github.com/kdlbs/kandev";
    changelog = "https://github.com/kdlbs/kandev/releases/tag/v${version}";
    license = lib.licenses.agpl3Only;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ mulatta ];
    mainProgram = "kandev";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
})
