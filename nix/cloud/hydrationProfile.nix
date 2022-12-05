{
  inputs,
  cell,
}: {
  # Bitte Hydrate Module
  # -----------------------------------------------------------------------
  #
  # reconcile with: `nix run .#clusters.[...].tf.hydrate-[cluster|app].(plan/apply)`
  default = {
    lib,
    config,
    bittelib,
    ...
  }: let
    inherit (inputs) cells;
  in {
    imports = [
      (inputs.bitte-cells.patroni.hydrationProfiles.hydrate-cluster ["infra"])
      cells.matterbridge.hydrationProfile.workload-policies-matterbridge
      cells.bors.hydrationProfile.workload-policies-bors
    ];

    # NixOS-level hydration
    # --------------
    cluster = {
      name = "clockworks";
      adminNames = ["shay.bergmann" "david.arnold"];
      domain = "cw.iog.io";
      kms = "arn:aws:kms:eu-central-1:337774054819:key/abfae3d9-60ee-41ed-a89a-63078cd5ed5d";
      s3Bucket = "iog-clockworks-bitte";
      s3Tempo = "cw-tempo";
    };

    services = {
      nomad.namespaces = {
        infra.description = "Painfully stateful stuff";
        prod.description = "Production services";
      };

      vault.policies.nomad-cluster = {
        path."consul/creds/matomo-analytics".capabilities = ["read"];
        path."auth/token/create/matomo-analytics".capabilities = ["update"];
        path."auth/token/roles/matomo-analytics".capabilities = ["read"];
      };
    };

    # cluster level
    # --------------
    tf.hydrate-cluster.configuration = {
      locals.policies = {
        vault.matomo-analytics = {
          path."kv/data/matomo-analytics/*".capabilities = ["read" "list"];
          path."kv/metadata/matomo-analytics/*".capabilities = ["read" "list"];
          path."consul/creds/matomo-analytics".capabilities = ["read"];
        };

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

    # Observability State
    # --------------
    tf.hydrate-monitoring.configuration = {
      resource =
        inputs.bitte-cells._utils.library.mkMonitoring
        # Alert attrset
        {
          # Cell Blocks local declared dashboards
          # inherit
          # (cell.alerts)
          # clockworks-example-alerts
          # Upstream alerts which may have downstream deps can be imported here
          # ;

          # Upstream alerts not having downstream deps can be directly imported here
          inherit
            (inputs.bitte-cells.bitte.alerts)
            bitte-consul
            bitte-deadmanssnitch
            bitte-loki
            bitte-system
            bitte-vault
            bitte-vm-health
            bitte-vm-standalone
            bitte-vmagent
            ;

          # Patroni not currently used in clockworks
          inherit
            (inputs.bitte-cells.patroni.alerts)
            bitte-cells-patroni
            ;
        }
        # Dashboard attrset
        {
          # Cell Blocks local declared dashboards
          # inherit
          # (cell.dashboards)
          # clockworks-example-dash
          # ;

          # Upstream dashboards not having downstream deps can be directly imported here
          inherit
            (inputs.bitte-cells.bitte.dashboards)
            bitte-consul
            bitte-log
            bitte-loki
            bitte-nomad
            bitte-system
            bitte-traefik
            bitte-vault
            bitte-vmagent
            bitte-vmalert
            bitte-vm
            bitte-vulnix
            ;

          # Patroni not currently used in clockworks
          inherit
            (inputs.bitte-cells.patroni.dashboards)
            bitte-cells-patroni
            ;
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
