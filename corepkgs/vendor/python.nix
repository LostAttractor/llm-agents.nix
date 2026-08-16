# Vendor a Python application + its runtime deps into a fixed-output derivation.
# `pip install --target` builds the app via its PEP 517 backend and resolves the
# full dependency closure from PyPI (manylinux wheels + pure-python), producing a
# flat site-packages tree we output. Like nixpkgs' pythonDepsHash it is one FOD
# with a committed hash (pip's per-file hashes are not a single fetchurl input).
#
# Determinism: --no-compile (no timestamped .pyc), and we strip the install
# bookkeeping that embeds the nondeterministic build path (RECORD, direct_url.json)
# or timestamps (__pycache__). Sdist-only deps that need a C compiler are out of
# scope (the manylinux wheel path is compiler-free).
{
  src,
  pythonDepsHash,
  sourceRoot ? null,
  postPatch ? "",
  system,
  python, # the python toolchain, threaded from the constructor scope
}:
let
  fetchurl = import ../fetch/fetchurl.nix;
  sys = (import ../systems.nix).${system};
  busybox = fetchurl {
    inherit (sys.busybox) url hash;
    executable = true;
  };
  script = ''
    set -eu
    __bb() { ( exec -a busybox "@busybox@" "$@" ); }
    __seedbin="$NIX_BUILD_TOP/.seed-bin"
    __bb mkdir -p "$__seedbin"
    __bb --install -s "$__seedbin"
    export PATH="@python@/bin:$__seedbin:$PATH"

    export HOME="$NIX_BUILD_TOP"
    export PIP_DISABLE_PIP_VERSION_CHECK=1

    tar -xzf "$src"
    cd "$(tar -tzf "$src" | head -1 | cut -d/ -f1)"
    [ -n "$sourceRoot" ] && cd "$sourceRoot"
    @postPatch@

    # build the app + resolve the whole runtime closure into a flat site tree
    python3 -m pip install --target "$out" --no-compile --no-warn-script-location .

    # strip nondeterministic install bookkeeping so the FOD hash is stable
    find "$out" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
    find "$out" \( -name 'RECORD' -o -name 'direct_url.json' \) -delete 2>/dev/null || true

    # pip's generated console scripts carry a `#!<toolchain python>` shebang, so
    # the tree would reference a store path - forbidden in a fixed-output
    # derivation (its hash can't capture referenced paths). mkPython regenerates
    # the launchers from `entrypoints`, so drop pip's bin/ entirely.
    rm -rf "$out/bin"
  '';
in
derivation {
  name = "python-vendor";
  inherit system src;
  sourceRoot = if sourceRoot == null then "" else sourceRoot;
  builder = "/bin/sh";
  args = [
    "-c"
    (builtins.replaceStrings
      [ "@busybox@" "@python@" "@postPatch@" ]
      [ "${busybox}" "${python}" postPatch ]
      script
    )
  ];
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = pythonDepsHash;
}
