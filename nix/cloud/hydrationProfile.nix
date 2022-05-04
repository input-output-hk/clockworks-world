{
  inputs,
  cell,
}: let
  inherit (inputs.bitte-cells) patroni cardano;
  namespaces = ["infra" "testnet-prod" "testnet-dev"];
  components = ["database" "cardano-node" "db-sync" "wallet"];
in {
  # Bitte Hydrate Module
  # -----------------------------------------------------------------------
  #
  # reconcile with: `nix run .#clusters.[...].tf.[app-|secrets-]hydrate.(plan/apply)`
  default = {
    lib,
    config,
    terralib,
    ...
  }: let
    inherit (terralib) allowS3For;
    bucketArn = "arn:aws:s3:::${config.cluster.s3Bucket}";
    allowS3ForBucket = allowS3For bucketArn;
    inherit (terralib) var id;
    c = "create";
    r = "read";
    u = "update";
    d = "delete";
    l = "list";
    s = "sudo";
    secretsFolder = "encrypted";
    starttimeSecretsPath = "kv/nomad-cluster";
    runtimeSecretsPath = "runtime";
  in {
    imports = [
      (patroni.hydrationProfiles.hydrate-cluster namespaces)
      (cardano.hydrationProfiles.hydrate-cluster namespaces)
    ];
    # NixOS-level hydration
    #
    # TODO: declare as proper tf hydration
    #
    # --------------
    cluster = {
      name = "cardano";
      adminNames = [
        "samuel.leathers"
        "david.arnold"
      ];
      developerGithubNames = [];
      developerGithubTeamNames = ["cardano-devs"];
      domain = "world.dev.cardano.org";
      extraAcmeSANs = [];
      kms = "arn:aws:kms:eu-central-1:052443713844:key/c1d7a205-5d3d-4ca7-8842-9f7fb2ccc847";
      s3Bucket = "iog-cardano-bitte";
    };
    services = {
      grafana.provision.dashboards = [
        {
          name = "provisioned-cardano";
          options.path = ./dashboards;
        }
      ];
      nomad.namespaces = {
        testnet-prod.description = "Cardano (testnet prod)";
        testnet-dev.description = "Cardano (testnet dev)";
        infra.description = "Painfully stateful stuff";
      };
    };
    # cluster level
    # --------------
    tf.hydrate-cluster.configuration = {
      locals.policies = {
        consul.developer.service_prefix."testnet-" = {
          policy = "write";
          intentions = "write";
        };

        nomad.admin.namespace."*".policy = "write";
        nomad.admin.host_volume."infra-*".policy = "write";

        nomad.developer.namespace.testnet-prod = {
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
        nomad.developer.namespace.testnet-dev = {
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

        nomad.developer.host_volume."testnet-prod-*".policy = "write";
        nomad.developer.host_volume."testnet-dev-*".policy = "write";
      };
    };
    # application secrets
    # --------------
    tf.hydrate-secrets.configuration = let
      _componentsXNamespaces = (
        lib.cartesianProductOfSets {
          namespace = namespaces;
          component = components;
          stage = ["starttime"];
          # stage = [ "runtime" "starttime" ];
        }
      );
      secretFile = g:
        ./.
        + "/${secretsFolder}/${g.namespace}/${g.component}-${g.namespace}-${g.stage}.enc.yaml";
      hasSecretFile = g: builtins.pathExists (secretFile g);
      secretsData.sops_file =
        builtins.foldl' (
          old: g:
            old
            // (
              lib.optionalAttrs (hasSecretFile g) {
                # Decrypting secrets from the files
                "${g.component}-secrets-${g.namespace}-${g.stage}".source_file = "${secretFile g}";
              }
            )
        ) {}
        _componentsXNamespaces;
      secretsResource.vault_generic_secret =
        builtins.foldl' (
          old: g:
            old
            // (
              lib.optionalAttrs (hasSecretFile g) (
                if g.stage == "starttime"
                then {
                  # Loading secrets into the generic kv secrets resource
                  "${g.component}-${g.namespace}-${g.stage}" = {
                    path = "${starttimeSecretsPath}/${g.namespace}/${g.component}";
                    data_json =
                      var "jsonencode(yamldecode(data.sops_file.${
                        g.component
                      }-secrets-${
                        g.namespace
                      }-${
                        g.stage
                      }.raw))";
                  };
                }
                else {
                  # Loading secrets into the generic kv secrets resource
                  "${g.component}-${g.namespace}-${g.stage}" = {
                    path = "${runtimeSecretsPath}/${g.namespace}/${g.component}";
                    data_json =
                      var "jsonencode(yamldecode(data.sops_file.${
                        g.component
                      }-secrets-${
                        g.namespace
                      }-${
                        g.stage
                      }.raw))";
                  };
                }
              )
            )
        ) {}
        _componentsXNamespaces;
    in {
      data = secretsData;
      resource = secretsResource;
    };
    # application state
    # --------------
    tf.hydrate-app.configuration = {};
  };
}
