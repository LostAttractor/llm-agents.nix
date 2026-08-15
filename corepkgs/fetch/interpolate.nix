# Nix mirror of Python's str.format for `{name}` placeholders. Unknown
# placeholders stay as-is (replaceStrings only touches given keys); extra vars
# are unused. Must stay in lockstep with scripts/updater/interpolate.py.
template: vars:
builtins.replaceStrings (map (name: "{${name}}") (
  builtins.attrNames vars
)) (builtins.attrValues vars) template
