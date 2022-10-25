{
  inputs,
  cell,
}: let
  inherit (inputs.std) std;
  inherit (inputs.std.lib) dev;
  inherit (inputs) capsules bitte-cells bitte nixpkgs;

  # FIXME: this is a work around just to get access
  # to 'awsAutoScalingGroups'
  # TODO: std ize bitte properly to make this interface nicer
  bitte' = inputs.bitte.lib.mkBitteStack {
    inherit inputs;
    inherit (inputs) self;
    domain = "cw.iog.io";
    bitteProfile = inputs.cells.metal.bitteProfile.default;
    hydrationProfile = inputs.cells.cloud.hydrationProfile.default;
    deploySshKey = "not-a-key";
  };

  cwWorld = {
    extraModulesPath,
    pkgs,
    ...
  }: {
    name = nixpkgs.lib.mkForce "Clockworks World";
    imports = [
      std.devshellProfiles.default
      bitte.devshellModule
    ];
    bitte = {
      domain = "cw.iog.io";
      cluster = "clockworks";
      namespace = "prod";
      provider = "AWS";
      cert = null;
      aws_profile = "clockworks";
      aws_region = "eu-central-1";
      aws_autoscaling_groups =
        bitte'.clusters.clockworks._proto.config.cluster.awsAutoScalingGroups;
    };
  };
in {
  dev = dev.mkShell {
    imports = [
      cwWorld
      capsules.base
      capsules.cloud
    ];
  };
  ops = dev.mkShell {
    imports = [
      cwWorld
      capsules.base
      capsules.cloud
      capsules.metal
      capsules.integrations
      capsules.tools
    ];
  };
}
