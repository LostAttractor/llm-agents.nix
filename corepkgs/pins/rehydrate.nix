# Pure-Nix rehydration of a serialized .drv closure (from `nix derivation show
# -r`), WITHOUT `nix derivation add` (no store mutation). We replay each node
# through `builtins.derivation`, re-attaching input dependencies via string
# context, so the reconstructed derivation is byte-identical to the original -
# same drvPath, same outputs - and therefore rebuildable from source on a cache
# miss. Durable: the closure JSON is the recipe; only hash-pinned source FODs
# need to persist upstream.
#
# `dump` = builtins.fromJSON of the `nix derivation show -r <drv>` output:
#   { derivations = { "<drvpath>" = <node>; ... }; }
# Returns a function drvPath -> the rehydrated derivation value.
dump:
let
  drvs = dump.derivations;
  storeDir = builtins.storeDir;

  # Auto env vars that `builtins.derivation` sets itself; never pass them back.
  autoEnv =
    node:
    [
      "name"
      "system"
      "builder"
      "outputs"
    ]
    ++ builtins.attrNames node.outputs;

  # A node's own output paths -> the self-reference placeholder Nix hashes with.
  # Original env bakes the resolved output path; derivation hashes self-refs as a
  # placeholder, so we must reverse that before handing env back. FOD outputs are
  # content-addressed (no `path`, and no self-refs), so skip them.
  selfSubst =
    node:
    builtins.concatMap (
      o:
      let
        out = node.outputs.${o};
      in
      if out ? path then
        [
          {
            from = "${storeDir}/${out.path}";
            to = builtins.placeholder o;
          }
        ]
      else
        [ ]
    ) (builtins.attrNames node.outputs);

  # Memoized fixpoint: reconstruct each node exactly once. The closure is a DAG
  # with heavy sharing (every node pulls the same bootstrap-tools/gcc/stdenv), so
  # naive recursion is exponential - inputs reference `memo`, not a re-call.
  reconNode =
    drvPath:
    let
      node = drvs.${drvPath};

      # 1. input derivations (memoized); collect their output paths as
      #    context-carrying strings (referencing the rebuilt input .drv).
      inputDrvSubst = builtins.concatLists (
        builtins.attrValues (
          builtins.mapAttrs (
            ipath: outs:
            let
              rd = memo.${ipath};
            in
            map (o: {
              from = "${(rd.${o}).outPath}"; # plain string of the input output path
              to = "${rd.${o}}"; # same string but carrying rd's derivation context
            }) outs.outputs
          ) node.inputs.drvs
        )
      );

      # 2. inputSrcs (store-names): reference each via storePath so it carries
      #    path context. These bottom out at the hash-pinned bootstrap sources.
      inputSrcSubst = map (
        s:
        let
          p = "${storeDir}/${s}";
        in
        {
          from = p;
          to = "${builtins.storePath p}";
        }
      ) node.inputs.srcs;

      subst = inputDrvSubst ++ inputSrcSubst ++ selfSubst node;
      froms = map (x: x.from) subst;
      tos = map (x: x.to) subst;
      recontext = v: if builtins.isString v then builtins.replaceStrings froms tos v else v;

      isFOD = (node.outputs.out or { }) ? hash;
      fodAttrs =
        if isFOD then
          {
            outputHash = node.outputs.out.hash; # SRI, self-describing algo
            outputHashAlgo = "";
            outputHashMode = node.outputs.out.method or "recursive";
          }
        else
          { };

      # `builtins.derivation` treats these attr names as booleans, but the .drv
      # env serializes them as "1"/"" strings - convert back or it type-errors.
      boolAttrs = [
        "__structuredAttrs"
        "preferLocalBuild"
        "allowSubstitutes"
        "__contentAddressed"
        "__impure"
      ];
      toBool = s: s == "1" || s == "true";
      userEnv0 = builtins.mapAttrs (_: recontext) (builtins.removeAttrs node.env (autoEnv node));
      userEnv =
        userEnv0
        // builtins.listToAttrs (
          map (k: {
            name = k;
            value = toBool userEnv0.${k};
          }) (builtins.filter (k: userEnv0 ? ${k}) boolAttrs)
        );
    in
    builtins.derivation (
      {
        inherit (node) name system;
        # builder is often an input derivation's output path (e.g. a bootstrap
        # seed) - recontext it too, or that dependency edge is lost.
        builder = recontext node.builder;
        args = map recontext node.args;
      }
      # Output order matters (it's hashed into the output paths). `attrNames`
      # sorts alphabetically; the real declaration order lives in env.outputs.
      # A single "out" output is the default - passing it would add an `outputs`
      # env var the original lacks, so only set it for multi-output.
      // (
        if node.env ? outputs then
          {
            outputs = builtins.filter (s: builtins.isString s && s != "") (builtins.split " " node.env.outputs);
          }
        else
          { }
      )
      // fodAttrs
      // userEnv
    );

  # the lazy self-referential memo: each drv reconstructed at most once.
  memo = builtins.mapAttrs (drvPath: _: reconNode drvPath) drvs;
in
drvPath: memo.${drvPath}
