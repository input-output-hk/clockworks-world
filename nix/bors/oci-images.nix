{
  inputs,
  cell,
}: let
  upstream = inputs.n2c.packages.nix2container.pullImage {
    imageName = "borsng/bors-ng";
    imageDigest = "sha256:6d2e69eae6f184f1dec79e1b1c15267d30b760274c74562ca0d95c369d0b8599";
    arch = "amd64";
    sha256 = "sha256-paJjE/52XGgULsofrJvjo0CQ5JSjrtecot18o4Ozf/4=";
  };
in {
  bors = inputs.n2c.packages.nix2container.buildImage {
    name = "registry.ci.iog.io/bors-ng";
    fromImage = upstream;
    maxLayers = 25;
    contents = [
      # doesn't work
      (inputs.nixpkgs.runCommand
        "sys.config"
        {}
        ''
          mkdir -p $out/app/bors/var $out/app/bors/releases/0.1.0
          cp ${./sys.config} $out/app/bors/var/sys.config
          cp ${./sys-release.config} $out/app/bors/releases/0.1.0/sys.config
        '')
    ];
    config.Cmd = [
      "./bors/bin/bors"
      "foreground"
    ];
    config.Entrypoint = ["/usr/local/bin/bors-ng-entrypoint"];
    config.WorkingDir = "/app";
  };
}
