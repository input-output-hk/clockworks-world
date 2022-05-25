{
  cell,
  inputs,
  domain,
  namespace,
  datacenters ? ["eu-central-1"],
}: let
  inherit (cell.library) ociNamer;
  inherit (cell) oci-images;
  inherit (inputs.nixpkgs) lib;
in {
  job.mysql = {
    inherit datacenters namespace;

    group.mysql = {
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

      network.port.mysql.to = "3306";

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
      ];

      task.mysql = {
        driver = "docker";

        config = {
          image = "mysql:8.0";
          ports = ["mysql"];
          command = "mysqld";
        };

        resources = {
          memory = 512;
          cpu = 300;
        };

        vault.policies = [];

        template = [
          {
            env = true;
            destination = "secrets/mysql";
            data = ''
              MYSQL_ROOT_PASSWORD={{with secret "kv/data/mysql/root-password"}}{{.Data.data}}{{end}}
            '';
          }
        ];
      };
    };
  };
}
