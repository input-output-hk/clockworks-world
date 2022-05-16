{
  inputs,
  cell,
}: let
  namespaces = ["infra" "matomo" "kroki" "ae-dir"];
  components = ["database"];
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
    # NixOS-level hydration
    #
    # TODO: declare as proper tf hydration
    #
    # --------------
    cluster = {
      name = "clockworks";
      adminNames = [
        "shay.bergmann"
      ];
      developerGithubNames = [];
      developerGithubTeamNames = ["devops"];
      domain = "cw.iog.io";
      extraAcmeSANs = [];
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
        matomo.description = "Matomo";
        kroki.description = "Kroki";
        ae-dir.description = "AE Dir";
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

        consul.admin.service_prefix."*" = {
          policy = "write";
          intentions = "write";
        };

        nomad.admin.host_volume."*".policy = "write";

        nomad.admin.namespace."*" = {
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
