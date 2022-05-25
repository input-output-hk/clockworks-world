{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (inputs.bitte-cells) _utils;
  inherit (cell) entrypoints packages healthChecks;
  n2c = inputs.n2c.packages.nix2container;

  buildDebugImage = ep: o: n2c.buildImage (_utils.library.mkDebugOCI ep o);

  tmp = nixpkgs.runCommand "tmp" {} ''
    mkdir -p $out/tmp
  '';
in {
  kroki = buildDebugImage entrypoints.kroki {
    name = "registry.ci.iog.io/kroki";
    maxLayers = 25;
    layers = [
      (n2c.buildLayer {deps = [packages.kroki];})
    ];
    contents = [nixpkgs.iana-etc];
    config.Env = [ "PATH=${nixpkgs.lib.makeBinPath [
      nixpkgs.bashInteractive
      nixpkgs.coreutils
      entrypoints.kroki
    ]}"];
    config.Cmd = [
      "${entrypoints.kroki}/bin/entrypoint"
    ];
  };
}
