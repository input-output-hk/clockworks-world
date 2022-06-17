{
  inputs,
  cell,
}: {
  # Bitte Hydrate Module
  # -----------------------------------------------------------------------
  #
  # reconcile with: `nix run .#clusters.[...].tf.[app-|secrets-]hydrate.(plan/apply)`
  default = {
    lib,
    config,
    terralib,
    bittelib,
    ...
  }: let
    inherit (terralib) allowS3For;
    bucketArn = "arn:aws:s3:::${config.cluster.s3Bucket}";
    allowS3ForBucket = allowS3For bucketArn;
    inherit (terralib) var id;
  in {
    # NixOS-level hydration
    #
    # TODO: declare as proper tf hydration
    #
    # --------------
    cluster = {
      name = "clockworks";
      adminNames = ["shay.bergmann"];
      domain = "cw.iog.io";
      kms = "arn:aws:kms:eu-central-1:337774054819:key/abfae3d9-60ee-41ed-a89a-63078cd5ed5d";
      s3Bucket = "iog-clockworks-bitte";
    };
    services = {
      grafana.provision.dashboards = [
        {
          name = "provisioned-clockworks";
          options.path = ./dashboards;
        }
      ];
      nomad.namespaces = {
        infra.description = "Painfully stateful stuff";
        prod.description = "Production services";
      };
    };
    # cluster level
    # --------------
    tf.hydrate-cluster.configuration = {

      locals.policies = {
        consul.developer.service_prefix."*" = {
          policy = "write";
          intentions = "write";
        };

        nomad.admin = {
          namespace."*".policy = "write";
          host_volume."*".policy = "write";
        };

        nomad.developer.host_volume."*".policy = "write";
        nomad.developer.namespace."*" = {
          policy = "write";
          capabilities = [
            "submit-job"
            "dispatch-job"
            "read-logs"
            "alloc-exec"
            "alloc-node-exec"
            "alloc-lifecycle"
          ];
        };
      };
    };
    # application state (terraform)
    # -----------------------------
    tf.hydrate-app.configuration = let
      vault' = {
        dir = ./. + "/kv/vault";
        prefix = "kv";
      };
      consul' = {
        dir = ./. + "/kv/consul";
        prefix = "config";
      };
      vault = bittelib.mkVaultResources {inherit (vault') dir prefix;};
      consul = bittelib.mkConsulResources {inherit (consul') dir prefix;};
    in {
      data = {inherit (vault) sops_file;};
      resource = {
        inherit (vault) vault_generic_secret;
        inherit (consul) consul_keys;
      };
    };
  };
}
