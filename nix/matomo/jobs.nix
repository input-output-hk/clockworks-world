{ cell
, inputs
,
}:
{
  default = { namespace, datacenters, ... }:
    let
      inherit (inputs) data-merge cells;
      ociNamer = oci: builtins.unsafeDiscardStringContext "${oci.imageName}:${oci.imageTag}";

      mkServiceMeta = { namespace, domain, jobname }: {
        address_mode = "auto";
        check = [
          {
            address_mode = "host";
            interval = "1m0s";
            port = "http";
            timeout = "2s";
            type = "tcp";
          }
        ];
        name = "${namespace}-nginx";
        port = "http";
        tags = [
          "${namespace}"
          "\${NOMAD_ALLOC_ID}"
          "ingress"
          "traefik.enable=true"
          "traefik.http.routers.matomo.rule=Host(`${jobname}.${domain}`)"
          "traefik.http.routers.matomo.entrypoints=https"
          "traefik.http.routers.matomo.tls.certresolver=acme"
        ];
      };
      secrets = {
        __toString = _: "kv/matomo-analytics/${namespace}";
        dbUser = ".Data.data.dbUser";
        dbPassword = ".Data.data.dbPassword";
      };
    in
    with data-merge;{
      job.matomo-analytics = {
        inherit datacenters namespace;
        vault.policies = [ "nomad-cluster" "matomo-analytics" ];

        group.matomo = {
          network.port.mysql.to = 3306;
          network.port.http.static = 8080;
          network.port.fastcgi.static = 9000;
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
              name = "mysql";
              address_mode = "auto";
              port = "mysql";
              check = [
                {
                  type = "tcp";
                  port = "mysql";
                  interval = "10s";
                  timeout = "2s";
                }
              ];
            }
            (mkServiceMeta {
              inherit namespace;
              domain = "cw.iog.io";
              jobname = "matomo";
            })

          ];

          task.nginx = {
            driver = "docker";

            config = {
              image = ociNamer cell.oci-images.matomo-nginx;
              ports = [ "http" ];
            };
            env.PHP_ADDRESS = "127.0.0.1:9000";

            resources = {
              memory = 1024;
              cpu = 300;
            };
          };

          task.matomo = {
            driver = "docker";

            config = {
              image = ociNamer cell.oci-images.matomo;
              ports = [ "fastcgi" ];
            };

            env = {
              MATOMO_DATABASE_HOST = "\${NOMAD_ADDR_mysql}";
              MATOMO_DATABASE_USERNAME = "my-user";
              MATOMO_DATABASE_PASSWORD = "super-complex-password-34892374982374";
              MATOMO_DATABASE_DBNAME = "my-matomo";
            };

            resources = {
              memory = 1024;
              cpu = 1000;
            };

            vault.policies = [ "nomad-cluster" "matomo-analytics" ];


            volume_mount = {
              destination = "/alloc/matomo";
              volume = "${namespace}-matomo";
            };
          };

          volume = {
            "${namespace}-matomo" = {
              source = "${namespace}-matomo";
              type = "host";
            };
            "${namespace}-matomo-db" = {
              source = "${namespace}-matomo-db";
              type = "host";
            };
          };

          task.mail = {
            driver = "docker";

            config = {
              image = "bytemark/smtp";
            };

            resources = {
              memory = 200;
              cpu = 300;
            };
          };


          task.mysql = {
            driver = "docker";

            config = {
              image = "mariadb:10.8.3";
              ports = [ "mysql" ];
            };

            resources = {
              memory = 1024;
              cpu = 300;
            };

            vault.policies = [ "nomad-cluster" "matomo-analytics" ];

            volume_mount = {
              destination = "/var/lib/mysql";
              volume = "${namespace}-matomo-db";
            };

            template = [
              {
                env = true;
                destination = "secrets/env";
                data = ''
                  {{with secret "${secrets}"}}
                  MARIADB_ROOT_PASSWORD={{ ${secrets.dbPassword} }}
                  {{- end }}
                '';
              }
            ];
          };
        };
      };
    };
}
