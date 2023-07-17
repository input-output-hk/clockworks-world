{ cell
, inputs
,
}:
{
  default = { namespace, datacenters, ... }:
    let
      inherit (inputs) data-merge cells;
      ociNamer = oci: builtins.unsafeDiscardStringContext "${oci.imageName}:${oci.imageTag}";
      check_restart = {
        limit = 2;
        grace = "60s";
        ignore_warnings = false;
      };

      mkServiceMeta = { namespace, domain, jobname }: {
        address_mode = "auto";
        #check = [
        #  {
        #    type = "http";
        #    path = "/";
        #    interval = "30s";
        #    timeout = "2s";
        #    inherit check_restart;
        #  }
        #];
        name = "${namespace}-matomo";
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
          network.port.http.static = 80;
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
            #{
            #  name = "mysql";
            #  address_mode = "auto";
            #  port = "mysql";
            #  check = [
            #    {
            #      type = "tcp";
            #      port = "mysql";
            #      interval = "10s";
            #      timeout = "2s";
            #    }
            #  ];
            #}
            (mkServiceMeta {
              inherit namespace;
              domain = "cw.iog.io";
              jobname = "matomo";
            })

          ];


          task.matomo = {
            driver = "docker";

            config = {
              image = "matomo:4.15.0-apache";
              ports = [ "http" ];
            };

            env.MATOMO_DATABASE_HOST = "\${NOMAD_ADDR_mysql}";

            resources = {
              memory = 4096;
              cpu = 2000;
            };

            vault.policies = [ "nomad-cluster" "matomo-analytics" ];


            volume_mount = {
              destination = "/var/www/html";
              volume = "${namespace}-matomo";
            };
          };



          task.mysql = {
            driver = "docker";

            config = {
              image = "mariadb:10.8.3";
              ports = [ "mysql" ];
            };

            resources = {
              memory = 8192;
              cpu = 3000;
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


        };
      };
    };
}
