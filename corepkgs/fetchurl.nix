# The naked layer's fetcher IS the repo's shared naked-fetchurl (lib/), which
# grew an `executable` option for this use. Re-exported here so naked/ modules
# keep their local `./fetchurl.nix` import path but there's one implementation.
import ./naked-fetchurl.nix
