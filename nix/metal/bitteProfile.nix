{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
in {
  default = {
    self,
    lib,
    pkgs,
    config,
    terralib,
    bittelib,
    ...
  }: let
    inherit (self.inputs) bitte;
    inherit (config) cluster;
    sr = {
      inherit
        (bittelib.securityGroupRules config)
        internet
        internal
        ssh
        http
        https
        routing
        ;
    };
  in {
    secrets.encryptedRoot = ./encrypted;

    nix = {
      binaryCaches = ["https://cache.iog.io"];
      binaryCachePublicKeys = ["hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0wEQ="];
    };

    cluster = {
      s3CachePubKey = lib.fileContents ./encrypted/nix-public-key-file;
      flakePath = "${inputs.self}";
      vbkBackend = "local";

      autoscalingGroups = let
        defaultModules = [(bitte + "/profiles/client.nix")];

        eachRegion = attrs: [
          (attrs // {region = "eu-central-1";})
          # (attrs // {region = "eu-west-1";})
          # (attrs // {region = "us-east-2";})
        ];
      in
        lib.listToAttrs
        (
          lib.forEach
          (
            (eachRegion {
              instanceType = "t3a.xlarge";
              desiredCapacity = 4;
              volumeSize = 500;
              modules =
                defaultModules
                ++ [
                  {
                    services.nomad.client.meta = {
                      cardano = "yeah";
                      patroni = "yeah";
                    };
                  }
                  (
                    bittelib.mkNomadHostVolumesConfig
                    ["infra-database"]
                    (n: "/var/lib/nomad-volumes/${n}")
                  )
                ];
              node_class = "infra";
            })
            ++
            # (eachRegion {
            #   instanceType = "t3.xlarge";
            #   volumeSize = 500;
            #   modules = defaultModules;
            #   node_class = "infra";
            # })
            # ++ (eachRegion {
            #   instanceType = "t3.2xlarge";
            #   volumeSize = 500;
            #   modules = defaultModules;
            #   node_class = "infra";
            # })
            # ++
            # Development NodeClass -- only one node
            [
              {
                region = "eu-central-1";
                instanceType = "t3a.xlarge";
                volumeSize = 500;
                modules = defaultModules;
                node_class = "development";
              }
            ]
          )
          (args: let
            attrs =
              {
                desiredCapacity = 1;
                instanceType = "t3a.large";
                associatePublicIP = true;
                maxInstanceLifetime = 0;
                iam.role = cluster.iam.roles.client;
                iam.instanceProfile.role = cluster.iam.roles.client;

                securityGroupRules = {inherit (sr) internet internal ssh;};
              }
              // args;
            asgName = "client-${attrs.region}-${
              builtins.replaceStrings [''.''] [''-''] attrs.instanceType
            }-${args.node_class}";
          in
            lib.nameValuePair asgName attrs)
        );

      instances = {
        core-1 = {
          instanceType = "t3a.medium";
          privateIP = "172.16.0.10";
          subnet = cluster.vpc.subnets.core-1;
          volumeSize = 100;

          modules = [
            (bitte + /profiles/core.nix)
            (bitte + /profiles/bootstrapper.nix)
          ];

          securityGroupRules = {inherit (sr) internet internal ssh;};
        };

        core-2 = {
          instanceType = "t3a.medium";
          privateIP = "172.16.1.10";
          subnet = cluster.vpc.subnets.core-2;
          volumeSize = 100;

          modules = [
            (bitte + /profiles/core.nix)
          ];

          securityGroupRules = {inherit (sr) internet internal ssh;};
        };

        core-3 = {
          instanceType = "t3a.medium";
          privateIP = "172.16.2.10";
          subnet = cluster.vpc.subnets.core-3;
          volumeSize = 100;

          modules = [
            (bitte + /profiles/core.nix)
          ];

          securityGroupRules = {inherit (sr) internet internal ssh;};
        };

        monitoring = {
          instanceType = "t3a.xlarge";
          privateIP = "172.16.0.20";
          subnet = cluster.vpc.subnets.core-1;
          volumeSize = 300;
          securityGroupRules = {inherit (sr) internet internal ssh http https;};
          modules = [
            (bitte + /profiles/monitoring.nix)
            {
              services.monitoring.useTempo = false;
              services.loki.configuration.table_manager = {
                retention_deletes_enabled = true;
                retention_period = "28d";
              };
            }
          ];
        };

        routing = {
          instanceType = "t3a.small";
          privateIP = "172.16.1.20";
          subnet = cluster.vpc.subnets.core-2;
          volumeSize = 30;
          securityGroupRules = {inherit (sr) internet internal ssh http https routing;};
          route53.domains = ["*.${cluster.domain}"];

          modules = [
            (bitte + /profiles/routing.nix)
            {
              services.oauth2_proxy.email.domains = ["iohk.io"];
              services.traefik.acmeDnsCertMgr = false;
              services.traefik.useVaultBackend = true;
              services.traefik.useDockerRegistry = false;
              services.traefik.enableTracing = false;
            }
          ];
        };

        # GlusterFS storage nodes
        storage-0 = {
          instanceType = "t3a.small";
          privateIP = "172.16.0.30";
          subnet = config.cluster.vpc.subnets.core-1;
          volumeSize = 40;
          modules = [(bitte + /profiles/storage.nix)];
          securityGroupRules = {inherit (sr) internal internet ssh;};
          ebsVolume = {
            iops = 3000; # 3000..16000
            size = 500; # GiB
            type = "gp3";
            throughput = 125; # 125..1000 MiB/s
          };
        };

        storage-1 = {
          instanceType = "t3a.small";
          privateIP = "172.16.1.30";
          subnet = config.cluster.vpc.subnets.core-2;
          volumeSize = 40;
          modules = [(bitte + /profiles/storage.nix)];
          securityGroupRules = {inherit (sr) internal internet ssh;};
          ebsVolume = {
            iops = 3000; # 3000..16000
            size = 500; # GiB
            type = "gp3";
            throughput = 125; # 125..1000 MiB/s
          };
        };

        storage-2 = {
          instanceType = "t3a.small";
          privateIP = "172.16.2.30";
          subnet = config.cluster.vpc.subnets.core-3;
          volumeSize = 40;
          modules = [(bitte + /profiles/storage.nix)];
          securityGroupRules = {inherit (sr) internal internet ssh;};
          ebsVolume = {
            iops = 3000; # 3000..16000
            size = 500; # GiB
            type = "gp3";
            throughput = 125; # 125..1000 MiB/s
          };
        };
      };
    };
  };
}
