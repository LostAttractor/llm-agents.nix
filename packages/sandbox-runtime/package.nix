# sandbox-runtime (srt) - built on corepkgs (nixpkgs-free) via mkNpm. Prebuilt
# registry tarball (dontNpmBuild); node_modules vendored from the committed lock.
# Ships a prebuilt native addon (@unrs/resolver-binding), so nativeAddons=true
# patchelfs it to the pinned glibc - keeps it store-only.
#
# NOTE: at runtime srt needs bubblewrap + socat + ripgrep on PATH (the nixpkgs
# recipe suffixes them via wrapProgram). corepkgs has no runtime-PATH mechanism
# yet, so for now they must be present in the environment.
{
  mkNpm,
  coreFetchurl,
  flake,
}:
mkNpm {
  pname = "sandbox-runtime";
  version = "0.0.73";
  src = coreFetchurl {
    url = "https://registry.npmjs.org/@anthropic-ai/sandbox-runtime/-/sandbox-runtime-0.0.73.tgz";
    hash = "sha256-FVVaHpGfbxFLprbk2TKJ3w139yrpKhI2d41EIbF6Zs4=";
  };
  packageLock = ./package-lock.json;
  npmDepsHash = "sha256-OYdUIyOV6TIaewr6QMX52ke1ifGjzE3I64gUXa1NGB4=";
  buildScript = "";
  nativeAddons = true;
  mainProgram = "srt";
  category = "Sandboxing & Isolation";
  meta = {
    description = "Lightweight sandboxing tool for enforcing filesystem and network restrictions";
    homepage = "https://github.com/anthropic-experimental/sandbox-runtime";
    changelog = "https://github.com/anthropic-experimental/sandbox-runtime/releases";
    license = flake.lib.licenses.asl20;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = [ ];
  };
}
