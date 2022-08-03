{
  description = "ClockWorks";
  inputs.std.url = "github:divnix/std";
  inputs.n2c.url = "github:nlewo/nix2container";
  inputs.data-merge.url = "github:divnix/data-merge";
  inputs = {
    # --- Bitte Stack ----------------------------------------------
    bitte.url = "github:input-output-hk/bitte";
    bitte-cells.url = "github:input-output-hk/bitte-cells/mariadb";
    # --------------------------------------------------------------
    # --- Auxiliaries ----------------------------------------------
    nixpkgs.follows = "bitte/nixpkgs";
    capsules.url = "github:input-output-hk/devshell-capsules";
    capsules.inputs.bitte.follows = "bitte";
  };
  outputs = inputs: let
    nomadEnvs = inputs.self.${system}.cloud.nomadEnvs;
    system = "x86_64-linux";
  in
    inputs.std.growOn {
      inherit inputs;
      cellsFrom = ./nix;
      #debug = ["cells" "cloud" "packages"];
      organelles = [
        (inputs.std.data "nomadEnvs")
        (inputs.std.data "constants")
        (inputs.std.functions "bitteProfile")
        (inputs.std.functions "oci-images")
        (inputs.std.installables "packages")
        (inputs.std.installables "config-data")
        (inputs.std.functions "hydrationProfile")
        (inputs.std.functions "devshellProfiles")
        # just repo automation; std - just integration pending
        (inputs.std.runnables "jobs")
        (inputs.std.runnables "entrypoints")
        (inputs.std.devshells "devshells")
      ];
    }
    # soil (TODO: eat up soil)
    (inputs.bitte.lib.mkBitteStack {
      inherit inputs;
      inherit (inputs) self;
      domain = "cw.iog.io";
      bitteProfile = inputs.self.${system}.metal.bitteProfile.default;
      hydrationProfile = inputs.self.${system}.cloud.hydrationProfile.default;
      deploySshKey = "./secrets/ssh-clockworks";
    }) {
      infra = inputs.bitte.lib.mkNomadJobs "infra" nomadEnvs;
      prod = inputs.bitte.lib.mkNomadJobs "prod" nomadEnvs;
    };
  # --- Flake Local Nix Configuration ----------------------------
  nixConfig = {
    extra-substituters = ["https://cache.iog.io"];
    extra-trusted-public-keys = ["hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="];
    # post-build-hook = "./upload-to-cache.sh";
    allow-import-from-derivation = "true";
  };
  # --------------------------------------------------------------
}
