{ cell
, inputs
,
}:
{
  default = { namespace, datacenters, ... }:
    let
      inherit (inputs) data-merge cells;

      secrets = {
        __toString = _: "kv/bors/${namespace}";
        config = ".Data.data.config";
      };
    in
    with data-merge;{
      job.bors = {
        inherit datacenters namespace;
        vault.policies = [ "nomad-cluster" "bors" ];

        group.bors = {
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
              name = "bors";
              address_mode = "auto";
            }
          ];

          task.bors = {
            driver = "docker";

            config.image = "borsng/bors-ng";
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
