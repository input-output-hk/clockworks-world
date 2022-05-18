{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (inputs.bitte-cells) _utils;
  inherit (cell) entrypoints packages healthChecks;
  n2c = inputs.n2c.packages.nix2container;

  buildDebugImage = ep: o: n2c.buildImage (_utils.library.mkDebugOCI ep o);
in {
  matomo = buildDebugImage entrypoints.matomo {
    name = "registry.ci.iog.io/matomo";
    maxLayers = 25;
    layers = [
      (n2c.buildLayer {deps = [nixpkgs.matomo];})
    ];
    contents = [nixpkgs.bashInteractive nixpkgs.iana-etc];
    config.Cmd = [
      "${entrypoints.matomo}/bin/entrypoint"
    ];
  };
}
