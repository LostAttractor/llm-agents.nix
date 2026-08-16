{
  lib,
  stdenv,
  darwin,
  flake,
  buildNpmPackage,
  nodejs_26,
  electron_41,
  hermes-agent,
  makeWrapper,
  xcbuild,
  icnsify,
  copyDesktopItems,
  makeDesktopItem,
  git,
  openssh,
  ripgrep,
  gh,
  curl,
  file,
  xprop,
  xdg-utils,
}:

let
  # Electron 40 is EOL in nixpkgs. Upstream pins 40.10.2 exactly because its
  # npm installer changed in later 40.x releases; Nix skips that installer and
  # supplies Electron separately. Keep the intentional major bump explicit and
  # rebuild node-pty against the runtime we actually ship.
  electron = electron_41;
  desktopVersion = "0.17.0";

  isLinux = stdenv.hostPlatform.isLinux;
  isDarwin = stdenv.hostPlatform.isDarwin;

  targetPlatform =
    if isLinux then
      "linux"
    else if isDarwin then
      "darwin"
    else
      throw "hermes-desktop: unsupported host platform ${stdenv.hostPlatform.system}";

  targetArch =
    if stdenv.hostPlatform.isAarch64 then
      "arm64"
    else if stdenv.hostPlatform.isx86_64 then
      "x64"
    else
      throw "hermes-desktop: unsupported host architecture ${stdenv.hostPlatform.system}";

  runtimeTools = [
    git
    openssh
    ripgrep
    gh
    curl
  ]
  ++ lib.optionals isLinux [
    xprop
    xdg-utils
  ];

  runtimePath = lib.makeBinPath runtimeTools;
  hermesExecutable = lib.getExe hermes-agent;
in
buildNpmPackage {
  pname = "hermes-desktop";
  version = desktopVersion;
  inherit (hermes-agent) src;

  # Desktop, TUI and web share one root package-lock.json. Reuse the FOD that
  # hermes-agent's frontend already fetched rather than storing the same npm
  # graph under a second hash.
  npmDeps = hermes-agent.hermes-frontend.npmDeps;
  nodejs = nodejs_26;

  # npmConfigHook already installs with --ignore-scripts. Keep its automatic
  # rebuild inert too: node-pty must be compiled manually for Electron's ABI,
  # not the build Node ABI, and Electron must never download a binary.
  npmRebuildFlags = [ "--ignore-scripts" ];
  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  dontNpmBuild = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals isLinux [ copyDesktopItems ]
  ++ lib.optionals isDarwin [
    file
    xcbuild
    icnsify
    darwin.autoSignDarwinBinariesHook
  ];

  buildPhase = ''
    runHook preBuild

    upstream_desktop_version=$(node -p "require('./apps/desktop/package.json').version")
    if [[ "$upstream_desktop_version" != ${lib.escapeShellArg desktopVersion} ]]; then
      echo "error: upstream Desktop version is $upstream_desktop_version, expected ${desktopVersion}" >&2
      echo "Update desktopVersion and re-check the package layout." >&2
      exit 1
    fi

    upstream_electron_manifest=$(node -p "require('./apps/desktop/package.json').devDependencies.electron")
    upstream_electron_builder=$(node -p "require('./apps/desktop/package.json').build.electronVersion")
    upstream_electron_lock=$(node -p "(p => (p['apps/desktop/node_modules/electron'] ?? p['node_modules/electron']).version)(require('./package-lock.json').packages)")
    if [[ "$upstream_electron_manifest" != 40.10.2 || "$upstream_electron_builder" != 40.10.2 || "$upstream_electron_lock" != 40.10.2 ]]; then
      echo "error: upstream Electron pins changed from the reviewed 40.10.2" >&2
      echo "manifest=$upstream_electron_manifest builder=$upstream_electron_builder lock=$upstream_electron_lock" >&2
      echo "Re-check Electron compatibility and update this package deliberately." >&2
      exit 1
    fi

    upstream_node_pty_manifest=$(node -p "require('./apps/desktop/package.json').dependencies['node-pty']")
    upstream_node_pty_lock=$(node -p "require('./package-lock.json').packages['node_modules/node-pty'].version")
    if [[ "$upstream_node_pty_manifest" != 1.1.0 || "$upstream_node_pty_lock" != 1.1.0 ]]; then
      echo "error: upstream node-pty pins changed from the reviewed 1.1.0" >&2
      echo "manifest=$upstream_node_pty_manifest lock=$upstream_node_pty_lock" >&2
      echo "Re-check native staging and Electron ABI compatibility." >&2
      exit 1
    fi

    mkdir -p apps/desktop/build

    ${lib.optionalString isLinux ''
      # External Electron points process.resourcesPath at its own installation.
      # Redirect only the Hermes install-stamp lookup to packaged resources.
      substituteInPlace apps/desktop/electron/main.ts \
        --replace-fail \
          "process.resourcesPath ? path.join(process.resourcesPath, 'install-stamp.json') : null," \
          "process.env.HERMES_DESKTOP_RESOURCES_DIR ? path.join(process.env.HERMES_DESKTOP_RESOURCES_DIR, 'install-stamp.json') : null,"
    ''}

    pushd apps/desktop

    # Vite empties dist/, so build the renderer before adding the Electron
    # main/preload bundles and staged native dependencies.
    npm exec -- tsc -b
    npm exec -- vite build
    node scripts/bundle-electron-main.mjs

    ${lib.optionalString isDarwin ''
      # Finder does not run the command-line wrapper and supplies only a small
      # PATH. Bake Nix defaults into the main bundle while still allowing an
      # explicit backend override from the launch environment.
      {
        printf '%s\n' \
          'process.env.HERMES_DESKTOP_HERMES ||= ${builtins.toJSON hermesExecutable};' \
          'process.env.PATH = ${builtins.toJSON runtimePath} + (process.env.PATH ? ":" + process.env.PATH : "");'
        cat dist/electron-main.mjs
      } > dist/electron-main.mjs.nix
      mv dist/electron-main.mjs.nix dist/electron-main.mjs
    ''}

    # Published prebuilds target other Node/Electron ABIs and are not usable on
    # NixOS. Force a native build using the headers for the Electron derivation
    # that the launcher below actually executes.
    rm -rf ../../node_modules/node-pty/build ../../node_modules/node-pty/prebuilds
    export npm_config_nodedir=${electron.headers}
    export npm_config_runtime=electron
    export npm_config_target=${electron.version}
    node ../../node_modules/node-gyp/bin/node-gyp.js rebuild \
      --directory=../../node_modules/node-pty \
      --build-from-source \
      --runtime=electron \
      --target=${electron.version} \
      --nodedir=${electron.headers} \
      --disturl= \
      --offline

    # Keep node-gyp dependency files out of both the initially staged tree and
    # electron-builder's beforePack restaging pass. The native addon and the
    # Darwin spawn-helper remain in Release/.
    rm -rf ../../node_modules/node-pty/build/Release/{.deps,node-addon-api,obj.target}

    node scripts/stage-native-deps.mjs ${targetPlatform} ${targetArch}
    rm -rf dist/node_modules/node-pty/build/Release/{.deps,node-addon-api,obj.target}

    ${lib.optionalString isDarwin ''
      # electron-builder's extraResources are required at runtime. The source
      # tarball has no .git metadata, so provide the same deterministic stamp
      # used by the Linux installation.
      cat > build/install-stamp.json <<'EOF'
      {"schemaVersion":1,"commit":"0000000000000000000000000000000000000000","branch":"main","dirty":false,"source":"nix"}
      EOF

      # Upstream's icon.icns is actually a PNG with the wrong extension.
      # Convert the source PNG up front so electron-builder neither packages an
      # invalid icon nor downloads its icon-conversion toolset in the sandbox.
      icnsify assets/icon.png --output assets/icon.icns

      # electron-builder mutates Electron.app while applying the Hermes bundle
      # identity, so copy nixpkgs' pinned dist to a writable build directory.
      # Supplying electronDist and disabling npm rebuild/download paths keeps
      # packaging fully offline; node-pty was already built for this runtime.
      rm -rf electron-dist
      mkdir electron-dist
      cp -R ${electron.dist}/. electron-dist/
      chmod -R u+w electron-dist
      export CSC_IDENTITY_AUTO_DISCOVERY=false

      # Fail closed if bundling gains another external, then remove source-only
      # dependencies. Returning false from beforeBuild marks node_modules as
      # externally handled while avoiding electron-builder 26's cycle-unsafe
      # workspace collector.
      node ${./prepare-packaging.mjs} .

      node scripts/run-electron-builder.mjs \
        -c.electronDist="$PWD/electron-dist" \
        -c.electronVersion=${electron.version} \
        -c.mac.identity=null \
        -c.mac.notarize=false \
        --dir --mac --arm64
    ''}

    popd

    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck

    npm run postbuild --workspace apps/desktop

    app=apps/desktop/dist
    test -f "$app/index.html"
    test -f "$app/electron-main.mjs"
    test -f "$app/electron-preload.js"
    test -f "$app/node_modules/node-pty/package.json"

    pty_node=$(find "$app/node_modules/node-pty" -name '*.node' -print -quit)
    test -n "$pty_node"

    spawn_helper=$(find "$app/node_modules/node-pty" -name spawn-helper -print -quit)
    if [[ -n "$spawn_helper" ]]; then
      test -x "$spawn_helper"
    fi

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    ${lib.optionalString isLinux ''
      appDir=$out/share/hermes-desktop
      mkdir -p "$appDir" $out/bin
      cp -r apps/desktop/dist "$appDir/"
      cp apps/desktop/package.json "$appDir/"

      # fetchFromGitHub has no .git directory. Use upstream's documented
      # non-git fallback rather than inventing a revision bootstrap may fetch.
      cat > "$appDir/install-stamp.json" <<EOF
      {"schemaVersion":1,"commit":"0000000000000000000000000000000000000000","branch":"main","dirty":false,"source":"nix"}
      EOF

      makeWrapper ${lib.getExe electron} $out/bin/hermes-desktop \
        --add-flags "$appDir" \
        --set HERMES_DESKTOP_HERMES ${lib.escapeShellArg hermesExecutable} \
        --set HERMES_DESKTOP_RESOURCES_DIR "$appDir" \
        --set ELECTRON_IS_DEV 0 \
        --prefix PATH : ${runtimePath} \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

      install -Dm644 apps/desktop/assets/icon.png \
        $out/share/icons/hicolor/1024x1024/apps/hermes-desktop.png
    ''}

    ${lib.optionalString isDarwin ''
      mapfile -t builtApps < <(find apps/desktop/release -type d -name Hermes.app -prune -print)
      if [[ "''${#builtApps[@]}" -ne 1 ]]; then
        echo "error: expected exactly one electron-builder Hermes.app, found ''${#builtApps[@]}" >&2
        printf '  %s\n' "''${builtApps[@]}" >&2
        exit 1
      fi

      mkdir -p $out/Applications $out/bin
      cp -R "''${builtApps[0]}" $out/Applications/Hermes.app

      # Finder bypasses this terminal entry point, so launch defaults are
      # embedded in electron-main.mjs.
      makeWrapper "$out/Applications/Hermes.app/Contents/MacOS/Hermes" \
        $out/bin/hermes-desktop
    ''}

    runHook postInstall
  '';

  desktopItems = lib.optionals isLinux [
    (makeDesktopItem {
      name = "hermes-desktop";
      desktopName = "Hermes";
      comment = "Native desktop shell for Hermes Agent";
      exec = "hermes-desktop %U";
      icon = "hermes-desktop";
      categories = [ "Development" ];
      mimeTypes = [ "x-scheme-handler/hermes" ];
      startupWMClass = "hermes";
    })
  ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    test -x $out/bin/hermes-desktop

    ${lib.optionalString isLinux ''
      appDir=$out/share/hermes-desktop
      ptyRoot="$appDir/dist/node_modules/node-pty"
      electronExecutable=${lib.getExe electron}

      test -f "$appDir/dist/index.html"
      test -f "$appDir/dist/electron-main.mjs"
      test -f "$appDir/dist/electron-preload.js"
      test -f "$appDir/install-stamp.json"
      test "$(node -p "require('$appDir/package.json').version")" = ${lib.escapeShellArg desktopVersion}
      grep -q HERMES_DESKTOP_HERMES $out/bin/hermes-desktop
      grep -q HERMES_DESKTOP_RESOURCES_DIR $out/bin/hermes-desktop
      grep -q ${lib.escapeShellArg hermesExecutable} $out/bin/hermes-desktop

      pty_node=$(find "$ptyRoot" -name '*.node' -print -quit)
      test -n "$pty_node"
      if ldd "$pty_node" | grep -q 'not found'; then
        ldd "$pty_node" >&2
        exit 1
      fi

      test -f $out/share/applications/hermes-desktop.desktop
    ''}

    ${lib.optionalString isDarwin ''
      app=$out/Applications/Hermes.app
      resources="$app/Contents/Resources"
      ptyRoot="$resources/app.asar.unpacked/dist/node_modules/node-pty"
      electronExecutable="$app/Contents/MacOS/Hermes"

      test -x "$electronExecutable"
      test -f "$app/Contents/Info.plist"
      plutil -lint "$app/Contents/Info.plist"
      grep -a -q '<string>com.nousresearch.hermes</string>' "$app/Contents/Info.plist"
      grep -a -q '<string>hermes</string>' "$app/Contents/Info.plist"
      grep -a -q '<key>NSMicrophoneUsageDescription</key>' "$app/Contents/Info.plist"
      bundleIcon=$(find "$resources" -maxdepth 1 -name '*.icns' -print -quit)
      test -n "$bundleIcon"
      file "$bundleIcon" | grep -Eq 'Mac OS X icon|Apple Icon Image'
      test -f "$resources/app.asar"
      test -f "$resources/install-stamp.json"
      test -f "$resources/icon.ico"
      test -f "$ptyRoot/package.json"
      test -f "$resources/app.asar.unpacked/dist/electron-main.mjs"
      grep -q ${lib.escapeShellArg hermesExecutable} \
        "$resources/app.asar.unpacked/dist/electron-main.mjs"
      grep -q ${lib.escapeShellArg runtimePath} \
        "$resources/app.asar.unpacked/dist/electron-main.mjs"

      file "$electronExecutable" | grep -Eq 'Mach-O.*arm64'
      pty_node=$(find "$ptyRoot" -name '*.node' -print -quit)
      test -n "$pty_node"
      file "$pty_node" | grep -Eq 'Mach-O.*arm64'
      spawn_helper=$(find "$ptyRoot" -name spawn-helper -print -quit)
      test -n "$spawn_helper"
      test -x "$spawn_helper"
      file "$spawn_helper" | grep -Eq 'Mach-O.*arm64'
    ''}

    # Loading verifies the compiled addon against the exact packaged Electron
    # ABI; spawning a PTY also exercises the macOS spawn-helper when applicable.
    HERMES_PTY_MODULE="$ptyRoot" \
      HERMES_PTY_SHELL=${stdenv.shell} \
      ELECTRON_RUN_AS_NODE=1 \
      "$electronExecutable" ${./pty-smoke.cjs}

    runHook postInstallCheck
  '';

  passthru = {
    category = "AI Assistants";
    agentVersion = hermes-agent.version;
    inherit desktopVersion electron;
  };

  meta = with lib; {
    description = "Official native Electron desktop shell for Hermes Agent";
    homepage = "https://hermes-agent.nousresearch.com/";
    changelog = "https://github.com/NousResearch/hermes-agent/releases/tag/v${hermes-agent.version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [
      fromSource
      binaryNativeCode
    ];
    maintainers = with flake.lib.maintainers; [ aliez-ren ];
    mainProgram = "hermes-desktop";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
}
