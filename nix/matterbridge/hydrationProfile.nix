{
  inputs,
  cell,
}: {
# Matterbridge
  workload-policies-matterbridge = {
    tf.hydrate-cluster.configuration.locals.policies = {
      vault.matterbridge = {
        path."kv/data/matterbridge/*".capabilities = ["read" "list"];
        path."kv/metadata/matterbridge/*".capabilities = ["read" "list"];
      };
    };
    # FIXME: consolidate policy reconciliation loop with TF
    # PROBLEM: requires bootstrapper reconciliation loop
    # clients need the capability to impersonate the `matterbridge` role
    services.vault.policies.client = {
      path."auth/token/create/matterbridge".capabilities = ["update"];
      path."auth/token/roles/matterbridge".capabilities = ["read"];
    };
  };
}
