{ inputs
, cell
,
}: {
  workload-policies-matomo = {
    tf.hydrate-cluster.configuration.locals.policies = {
      vault.matomo = {
        path."kv/data/matomo-analytics/*".capabilities = [ "read" "list" ];
        path."kv/metadata/matomo-analytics/*".capabilities = [ "read" "list" ];
        path."consul/creds/matomo-analytics".capabilities = [ "read" ];
      };
    };
    # FIXME: consolidate policy reconciliation loop with TF
    # PROBLEM: requires bootstrapper reconciliation loop
    # clients need the capability to impersonate the `matomo-analytics` role
    services.vault.policies.client = {
      path."consul/creds/matomo-analytics".capabilities = [ "read" ];
      path."auth/token/create/matomo-analytics".capabilities = [ "update" ];
      path."auth/token/roles/matomo-analytics".capabilities = [ "read" ];
    };
  };
}
