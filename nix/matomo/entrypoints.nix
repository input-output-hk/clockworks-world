{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (inputs.bitte-cells._writers.library) writeShellApplication;
  inherit (cell) packages;

  cfgFile = nixpkgs.writeText "phpfpm-matomo.conf" ''
    [global]
    error_log = /dev/stderr
    daemonize = no

    [matomo]
    user = matomo
    group = matomo
    listen = 127.0.0.1:9000
    pm = dynamic
    pm.max_children = 75
    pm.start_servers = 10
    pm.min_spare_servers = 5
    pm.max_spare_servers = 20
    pm.max_requests = 500
    catch_workers_output = yes
    env[PIWIK_USER_PATH] = /alloc/matomo
  '';

  iniFile = nixpkgs.runCommand "php.ini" {
    phpOptions = ''
      error_log = 'stderr'
      log_errors = on
    '';
    preferLocalBuild = true;
    passAsFile = [ "phpOptions" ];
  } ''
    cat ${nixpkgs.php}/etc/php.ini $phpOptionsPath > $out
  '';
in {
  matomo = writeShellApplication {
    name = "entrypoint";
    text = ''
      exec ${nixpkgs.php}/bin/php-fpm -y ${cfgFile} -c ${iniFile}
    '';
  };
}
