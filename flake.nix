{
  description = "ClockWorks";
  inputs.std.url = "github:divnix/std";
  inputs.n2c.follows = "std/n2c";
  inputs.data-merge.follows = "std/dmerge";
  inputs = {
    # --- Bitte Stack ----------------------------------------------
    bitte.url = "github:input-output-hk/bitte";
    bitte-cells.url = "github:input-output-hk/bitte-cells";
    # --------------------------------------------------------------
    # --- Auxiliaries ----------------------------------------------
    nixpkgs.url = "github:NixOS/nixpkgs";
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
      cellBlocks = with inputs.std.blockTypes; [
        (data "nomadEnvs")
        (data "constants")
        (data "alerts")
        (data "dashboards")
        (functions "bitteProfile")
        (containers "oci-images")
        (installables "packages")
        (installables "config-data")
        (functions "hydrationProfile")
        (functions "devshellProfiles")
        # just repo automation; std - just integration pending
        (runnables "jobs")
        (runnables "entrypoints")
        (devshells "devshells")
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
