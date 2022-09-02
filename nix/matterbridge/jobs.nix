{ cell
, inputs
,
}:
{
  default = { namespace, datacenters, ... }:
    let
      inherit (inputs) data-merge cells;
      ociNamer = oci: builtins.unsafeDiscardStringContext "${oci.imageName}:${oci.imageTag}";

      secrets = {
        __toString = _: "kv/matterbridge/${namespace}";
        config = ".Data.data.config";
      };
    in
    with data-merge;{
      job.matterbridge = {
        inherit datacenters namespace;
        vault.policies = [ "nomad-cluster" "matterbridge" ];

        group.matterbridge = {
          network.mode = "bridge";

          restart = {
            attempts = 5;
            delay = "10s";
            interval = "1m";
            mode = "delay";
          };

          reschedule = {
            delay = "10s";
            delay_function = "exponential";
            max_delay = "1m";
            unlimited = true;
          };

          service = [
            {
              name = "matterbridge";
              address_mode = "auto";
            }
          ];

          task.matterbridge = {
            driver = "docker";

            config.image = ociNamer cell.oci-images.matterbridge;
            # env.DEBUG_SLEEP = "600";

            resources = {
              memory = 1024;
              cpu = 300;
            };

            template = [
              {
                destination = "secrets/config.toml";
                data = ''{{with secret "${secrets}"}}{{ ${secrets.config} }}{{- end }}'';
              }
            ];
          };
        };
      };
    };
}
