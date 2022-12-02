{
  inputs,
  cell,
}: {
# Matterbridge
  workload-policies-bors = {
    tf.hydrate-cluster.configuration.locals.policies = {
      vault.bors = {
        path."kv/data/bors/*".capabilities = ["read" "list"];
        path."kv/metadata/bors/*".capabilities = ["read" "list"];
      };
    };
    # FIXME: consolidate policy reconciliation loop with TF
    # PROBLEM: requires bootstrapper reconciliation loop
    # clients need the capability to impersonate the `bors` role
    services.vault.policies.client = {
      path."auth/token/create/bors".capabilities = ["update"];
      path."auth/token/roles/bors".capabilities = ["read"];
    };
  };
}
