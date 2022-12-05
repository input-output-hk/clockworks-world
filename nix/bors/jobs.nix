{
  cell,
  inputs,
}: {
  default = {
    namespace,
    datacenters,
    domain,
    ...
  }: let
    url = "bors.${domain}";
    secrets = {
      __toString = _: "kv/bors/${namespace}";
      pem = ".Data.data.integration";
      client = ".Data.data.client";
      webhook = ".Data.data.webhook";
      keybase = ".Data.data.key_base";
      dbPass = ".Data.data.database_pw";
    };
  in {
    job.bors = {
      inherit datacenters namespace;
      vault.policies = ["bors"];

      group.bors = {
        network.mode = "bridge";
        network.port.bors = {};

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

        task.bors = {
          driver = "docker";

          config.image = cell.oci-images.bors.imageRefUnsafe;
          # env.DEBUG_SLEEP = "600";

          resources = {
            memory = 1024;
            cpu = 1000;
          };

          env = {
            PUBLIC_HOST = url;
            ALLOW_PRIVATE_REPOS = true;
            COMMAND_TRIGGER = "bors";
            GITHUB_CLIENT_ID = "Iv1.17382ed95b58d1a8";
            GITHUB_INTEGRATION_ID = 17473;
            DATABASE_AUTO_MIGRATE = true;
          };

          template = [
            {
              change_mode = "restart";
              data = let
                getSecret = secret: ''{{ with secret "${secrets}" }}{{${secret}}}{{end}}'';
                user = "bors-ng";
                pass = getSecret secrets.dbPass;
                address = "_infra-database._master.service.eu-central-1.consul";
                db = "bors-ng";
              in ''
                SECRET_KEY_BASE=${getSecret secrets.keybase}
                GITHUB_CLIENT_SECRET=${getSecret secrets.client}
                GITHUB_INTEGRATION_PEM=${getSecret secrets.pem}
                GITHUB_WEBHOOK_SECRET=${getSecret secrets.webhook}
                DATABASE_URL=postgres://${user}:${pass}@${address}:5432/${db}
                PORT={{ env "NOMAD_PORT_bors" }}
              '';
              destination = "secrets/env";
              env = true;
            }
          ];

          service = [
            {
              address_mode = "auto";
              check = [
                {
                  address_mode = "host";
                  check_restart = [{grace = "1m0s";}];
                  interval = "30s";
                  method = "GET";
                  path = "/health";
                  port = "bors";
                  protocol = "http";
                  timeout = "3s";
                  type = "http";
                }
              ];
              name = "${namespace}-bors";
              port = "bors";
              tags = [
                "${namespace}"
                "\${NOMAD_ALLOC_ID}"
                "ingress"
                "traefik.enable=true"
                "traefik.http.routers.bors.rule=Host(`${url}`)"
                "traefik.http.routers.bors.entrypoints=https"
                "traefik.http.routers.bors.tls.certresolver=acme"
              ];
            }
          ];
        };
      };
    };
  };
}
