# skills - built on corepkgs (nixpkgs-free) via mkNpm. Prebuilt registry tarball
# (dontNpmBuild); node_modules vendored from the committed lock. Ships prebuilt
# native addons (@rolldown/binding, lightningcss), so nativeAddons=true patchelfs
# them to the pinned glibc (the autoPatchelfHook equivalent) - keeps it store-only.
{
  mkNpm,
  coreFetchurl,
  flake,
}:
mkNpm {
  pname = "skills";
  version = "1.5.22";
  src = coreFetchurl {
    url = "https://registry.npmjs.org/skills/-/skills-1.5.22.tgz";
    hash = "sha256-EM7jkTnevmwBiPRycZSt5ZI0snfMyiMg4+1rYg7n8Us=";
  };
  packageLock = ./package-lock.json;
  npmDepsHash = "sha256-OFkWnpgtXqWNVnoE/FrwcF8MB1AJpk5DuJbNJHEqNus=";
  buildScript = "";
  nativeAddons = true;
  category = "Skills & Plugins";
  meta = {
    description = "The open agent skills tool for installing and managing skills across AI coding agents";
    homepage = "https://github.com/vercel-labs/skills";
    changelog = "https://github.com/vercel-labs/skills/releases/tag/v1.5.22";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    maintainers = with flake.lib.maintainers; [ kusold ];
  };
}
