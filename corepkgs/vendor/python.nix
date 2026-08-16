# Vendor a Python app + its runtime deps as ONE fixed-output derivation. `pip
# install --target` builds the app via its PEP 517 backend and resolves the full
# closure from PyPI (manylinux wheels + pure-python) into a flat site tree we
# output. pip's per-file hashes aren't a single fetchurl input, so it's one
# committed-hash FOD.
#
# Determinism: --no-compile (no timestamped .pyc), and strip install bookkeeping
# that embeds the build path (RECORD, direct_url.json) or timestamps
# (__pycache__). Sdist-only C-compile deps are out of scope (wheels are compiler-free).
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
  sys = (import ../seed/systems.nix).${system};
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

    # pip's console scripts carry a `#!<toolchain python>` shebang -> the tree
    # references a store path, forbidden in a FOD (its hash can't capture refs).
    # mkPython regenerates launchers from `entrypoints`, so drop pip's bin/.
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
