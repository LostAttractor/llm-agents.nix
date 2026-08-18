{
  lib,
  mkUpdater,
  stdenv,
  makeWrapper,
  wrapBuddy,
  ripgrep,
  platformSource,
  versionCheckHook,
  versionCheckHomeHook,
  flake,
}:

let
  # OpenCode 2 ships as platform-specific Bun executables on npm's next channel
  # (@opencode-ai/cli-<platform>).
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
      aarch64-darwin = "darwin-arm64";
    };
    urlTemplate = "https://registry.npmjs.org/@opencode-ai/cli-{platform}/-/cli-{platform}-{version}.tgz";
  };
in
stdenv.mkDerivation {
  pname = "opencode2";
  inherit (source) version src;

  sourceRoot = "package";

  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals stdenv.hostPlatform.isLinux [ wrapBuddy ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  wrapBuddyExtraNeeded = lib.optionals stdenv.hostPlatform.isLinux [ "libstdc++.so.6" ];

  dontBuild = true;
  # Bun-compiled executable; stripping corrupts the embedded payload.
  dontStrip = true;

  # Install only the executable; the tarball also contains ~49 MiB of source
  # maps that are not needed at runtime.
  installPhase = ''
    runHook preInstall

    install -Dm755 bin/opencode2 $out/bin/opencode2
    wrapProgram $out/bin/opencode2 \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = "--version";

  passthru.category = "AI Coding Agents";
  passthru.updater = mkUpdater (
    source.updater
    // {
      versionSource = {
        type = "npm";
        package = "@opencode-ai/cli";
        tag = "next";
      };
      versionPolicy = "follow_pointer";
    }
  );

  meta = {
    description = "OpenCode 2 preview CLI";
    longDescription = ''
      OpenCode 2 is the preview of OpenCode's next-generation CLI. The single
      executable includes the terminal interface and server, and can run with
      a private server, reuse a background service, or connect to a remote
      server.
    '';
    homepage = "https://opencode.ai";
    changelog = "https://github.com/anomalyco/opencode/commits/v2";
    downloadPage = "https://www.npmjs.com/package/@opencode-ai/cli?activeTab=versions";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with flake.lib.maintainers; [ iainlane ];
    mainProgram = "opencode2";
    platforms = source.platforms;
  };
}
