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
  matterbridge = buildDebugImage entrypoints.matterbridge {
    name = "registry.ci.iog.io/matterbridge";
    maxLayers = 25;
    layers = [
      (n2c.buildLayer {deps = [packages.matterbridge];})
    ];
    contents = [nixpkgs.cacert];
    config.Env = [
      "PATH=${nixpkgs.lib.makeBinPath [
        nixpkgs.bashInteractive
        nixpkgs.coreutils
        entrypoints.matterbridge
      ]}"
    ];
    config.Cmd = [
      "${entrypoints.matterbridge}/bin/entrypoint"
    ];
  };
}
