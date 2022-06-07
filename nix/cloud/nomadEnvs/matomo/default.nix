{
  namespace,
  datacenters,
  ...
}: {
  job.matomo = {
    inherit datacenters namespace;

    group.matomo = {
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

      task.matomo = {
        driver = "docker";

        config = {
          image = "registry.ci.iog.io/matomo";
          # ports = ["mysql"];
          # command = "mysqld";
        };

        resources = {
          memory = 1024;
          cpu = 300;
        };

        vault.policies = ["nomad-cluster"];

        # template = [
        #   {
        #     env = true;
        #     destination = "secrets/mysql";
        #     data = ''
        #       MARIADB_ROOT_PASSWORD={{with secret "kv/data/nomad-cluster/mysql-root"}}{{.Data.data.password}}{{end}}
        #     '';
        #   }
        # ];
      };
    };
  };
}
