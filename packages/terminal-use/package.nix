# terminal-use - built from source on corepkgs (nixpkgs-free) via mkCargo. Pure
# crates.io deps; installs the `tu` binary. Upstream ships a placeholder 0.0.0
# manifest version that its release workflow rewrites at tag time, so `tu
# --version` reports 0.0.0 here (we do not run the substituteInPlace tweak).
{
  mkCargo,
  coreFetchurl,
  flake,
}:
mkCargo {
  pname = "terminal-use";
  version = "1.2.0";
  src = coreFetchurl {
    url = "https://github.com/flipbit03/terminal-use/archive/refs/tags/v1.2.0.tar.gz";
    hash = "sha256-B2XJtaJzPxt91vtndcRX2TBLB9AFfrzSTsJf3Z38cNk=";
  };
  cargoLock = ./Cargo.lock;
  binaries = [ "tu" ];

  category = "Utilities";
  meta = {
    description = "Headless virtual terminal for AI agents";
    longDescription = ''
      tu is a full terminal emulator for AI agents. It spawns interactive
      terminal apps and lets an agent read the rendered screen (as text or PNG
      screenshot) and drive the keyboard and mouse — no GUI, X server, or
      display needed. Multiple sessions can run at once, like tmux for an
      agent.
    '';
    homepage = "https://github.com/flipbit03/terminal-use";
    changelog = "https://github.com/flipbit03/terminal-use/releases/tag/v1.2.0";
    license = flake.lib.licenses.mit;
    sourceProvenance = [ flake.lib.sourceTypes.fromSource ];
    mainProgram = "tu";
    maintainers = [ flake.lib.maintainers.mic92 ];
  };
}
