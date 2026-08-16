# The corepkgs's fetcher IS the repo's shared builtin-fetchurl (lib/), which
# grew an `executable` option for this use. Re-exported here so fetch/ modules
# keep their local `./fetchurl.nix` import path but there's one implementation.
import ./builtin-fetchurl.nix
