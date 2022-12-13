{ inputs
, cell
,
}:
let
  inherit (inputs) nixpkgs;
  inherit (inputs.bitte-cells) _utils;
  inherit (cell) entrypoints packages healthChecks;
  inherit (nixpkgs) lib;
  n2c = inputs.n2c.packages.nix2container;

  buildDebugImage = ep: o: n2c.buildImage (_utils.library.mkDebugOCI ep o);

  bin = nixpkgs.buildEnv {
    name = "bin";
    paths = [
      nixpkgs.bashInteractive
      nixpkgs.coreutils
      nixpkgs.strace
      nixpkgs.exim
      entrypoints.matomo.passthru.matomo
    ];
    pathsToLink = "/bin";
  };

  tmp = nixpkgs.runCommand "tmp" { } ''
    mkdir -p $out/tmp/empty
  '';

  etc = nixpkgs.runCommand "etc" { } ''
    mkdir -p $out/etc
    ln -s ${entrypoints.matomo.passthru.matomo}/share $out/matomo
    if [[ ! -f $out/etc/passwd ]]; then
      echo "root:x:0:0::/root:/nix/store/${nixpkgs.bashInteractive}/bin/bash" > $out/etc/passwd
      echo "root:!x:::::::" > $out/etc/shadow
      echo "matomo:x:1000:1000::/var/lib/matomo:/nix/store/${nixpkgs.bashInteractive}/bin/bash" > $out/etc/passwd
      echo "matomo:!x:::::::" > $out/etc/shadow
    fi
    if [[ ! -f $out/etc/group ]]; then
      echo "root:x:0:" > $out/etc/group
      echo "root:x::" > $out/etc/gshadow
      echo "matomo:x:1000:" > $out/etc/group
      echo "matomo:x::" > $out/etc/gshadow
    fi
  '';
in
{
  matomo = buildDebugImage entrypoints.matomo {
    name = "registry.ci.iog.io/matomo";
    maxLayers = 25;
    layers = [
      (n2c.buildLayer {
        deps = [ entrypoints.matomo.passthru.matomo ];

        perms = [
          {
            path = entrypoints.matomo.passthru.matomo;
            regex = ".*";
            mode = "0777";
          }
        ];
      })
    ];
    contents = [
      bin
      etc
      tmp
      nixpkgs.iana-etc
    ];
    config.Env = [
      "PATH=/bin"
      "USER=matomo"
    ];
    config.User = "1000:1000";
    config.Cmd = [
      "${entrypoints.matomo}/bin/entrypoint"
    ];
    perms = [
      {
        path = tmp;
        regex = ".*";
        mode = "0777";
      }
      {
        path = entrypoints.matomo.passthru.matomo;
        regex = ".*";
        mode = "0777";
      }
    ];
  };


  matomo-nginx =
    let
      nginxFS = nixpkgs.runCommand "nginx-fs" { } ''
        mkdir -p $out/{etc,tmp}
        mkdir -p $out/var/log/nginx
        mkdir -p $out/var/cache/nginx
        ln -s ${entrypoints.matomo.passthru.matomo}/share $out/matomo

        if [[ ! -f $out/etc/passwd ]]; then
          echo "root:x:0:0::/root:/nix/store/${nixpkgs.bashInteractive}/bin/bash" > $out/etc/passwd
          echo "root:!x:::::::" > $out/etc/shadow
          echo "nobody:x:1000:1000::/var/lib/matomo:/nix/store/${nixpkgs.bashInteractive}/bin/bash" > $out/etc/passwd
          echo "nobody:!x:::::::" > $out/etc/shadow
        fi
        if [[ ! -f $out/etc/group ]]; then
          echo "root:x:0:" > $out/etc/group
          echo "root:x::" > $out/etc/gshadow
          echo "nogroup:x:1000:" > $out/etc/group
          echo "nogroup:x::" > $out/etc/gshadow
        fi
        if [[ ! -f $out/etc/subuid ]]; then
          echo "nobody:0:65536" > $out/etc/subuid
        fi
      '';
    in
    n2c.buildImage {
      name = "registry.ci.iog.io/matomo-nginx";
      copyToRoot = [ nginxFS ];
      config = {
        Cmd = [ "${entrypoints.matomoNginx}/bin/entrypoint" ];
        ExposedPorts = {
          "8080/tcp" = { };
        };
      };
    };
}
