{
  lib,
  stdenv,
  fetchzip,
  nodejs,
  versionCheckHook,
  versionCheckHomeHook,
}:

stdenv.mkDerivation rec {
  pname = "ccusage-amp";
  version = "19.0.0";

  src = fetchzip {
    url = "https://registry.npmjs.org/@ccusage/amp/-/amp-${version}.tgz";
    hash = "sha256-iji8JpIADwtxx/zi+jKmtchPl/OJKMnEUFeTdVp7HL4=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    install -Dm755 index.js $out/bin/ccusage-amp

    substituteInPlace $out/bin/ccusage-amp \
      --replace-fail "#!/usr/bin/env node" "#!${nodejs}/bin/node"

    runHook postInstall
  '';

  doInstallCheck = true;

  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Usage Analytics";

  meta = with lib; {
    description = "Usage analysis tool for Amp CLI sessions";
    homepage = "https://github.com/ryoppippi/ccusage";
    changelog = "https://github.com/ryoppippi/ccusage/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with maintainers; [ ryoppippi ];
    mainProgram = "ccusage-amp";
    platforms = platforms.all;
  };
}
