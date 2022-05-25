{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (inputs.bitte-cells) _utils;
  inherit (cell) entrypoints packages healthChecks;
  n2c = inputs.n2c.packages.nix2container;

  buildDebugImage = ep: o: n2c.buildImage (_utils.library.mkDebugOCI ep o);

  tmp = nixpkgs.runCommand "tmp" {} ''
    mkdir -p $out/tmp
  '';
  etc = nixpkgs.runCommand "etc" {} ''
     mkdir -p $out/etc
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
in {
  matomo = buildDebugImage entrypoints.matomo {
    name = "registry.ci.iog.io/matomo";
    maxLayers = 25;
    layers = [
      (n2c.buildLayer {deps = [nixpkgs.matomo];})
    ];
    contents = [
      tmp
      etc
      nixpkgs.iana-etc
    ];
    config.Env = [
      "PATH=${nixpkgs.lib.makeBinPath [
        nixpkgs.bashInteractive
        nixpkgs.coreutils
        entrypoints.matomo
        nixpkgs.strace
      ]}"
    ];
    config.Cmd = [
      "${entrypoints.matomo}/bin/entrypoint"
    ];
    perms = [
      {
        path = tmp;
        regex = ".*";
        mode = "0777";
      }
    ];
  };
}
