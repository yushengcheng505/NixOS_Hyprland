{ config, pkgs, ... }:

let
  packageManifestEntries = pkgs.lib.concatMap (
    package:
    let
      selectedOutputs =
        (if !(package.outputSpecified or false) && (package.meta.outputsToInstall or null) != null
        then map (name: package.${name}) package.meta.outputsToInstall
        else [ package ])
        ++ pkgs.lib.concatMap (
          name: pkgs.lib.optional (builtins.hasAttr name package) package.${name}
        ) config.environment.extraOutputsToInstall;
      metadata = package.meta or { };
      homepage = metadata.homepage or "";
    in
    map (output: {
      storePath = toString output;
      name = pkgs.lib.getName package;
      version = package.version or "";
      outputName = output.outputName or "out";
      description = if builtins.isString (metadata.description or "") then metadata.description or "" else "";
      homepage = if builtins.isString homepage then homepage
        else if builtins.isList homepage then pkgs.lib.concatStringsSep " " (builtins.filter builtins.isString homepage)
        else "";
    }) selectedOutputs
  ) config.environment.systemPackages;
  packageManifest = builtins.attrValues (builtins.listToAttrs (
    map (package: { name = builtins.unsafeDiscardStringContext package.storePath; value = package; }) packageManifestEntries
  ));
in
{
  environment.etc."cartoon-shell/system-packages.json".text = builtins.toJSON {
    schemaVersion = 1;
    packages = packageManifest;
  };
}
