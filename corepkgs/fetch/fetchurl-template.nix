# fetchurl with a templated URL. The single templated-URL primitive shared by a
# package's build and its declarative updater, so the two can never fetch
# different URLs. Extra args (hash, name, ...) pass through to fetchurl.
{ fetchurl, interpolate }:

{
  urlTemplate,
  vars,
  ...
}@args:
fetchurl (
  (builtins.removeAttrs args [
    "urlTemplate"
    "vars"
  ])
  // {
    url = interpolate urlTemplate vars;
  }
)
