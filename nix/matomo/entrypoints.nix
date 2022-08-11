{ inputs, cell }:
let
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

  iniFile =
    nixpkgs.runCommand "php.ini"
      {
        phpOptions = ''
          sendmail_path = "${nixpkgs.busybox}/bin/sendmail -i -t"
          error_log = 'stderr'
          log_errors = on
          [General]
          enable_trusted_host_check=0
          [opcache]
          opcache.memory_consumption = 196
          opcache.log_verbosity_level = 4
        '';
        preferLocalBuild = true;
        passAsFile = [ "phpOptions" ];
      } ''
      cat ${nixpkgs.php}/etc/php.ini $phpOptionsPath > $out
    '';
  dataDir = "/alloc/matomo";

  nginxConf = nixpkgs.writeText "nginx.conf" ''
    error_log /dev/stderr;
    daemon off;
    events { }
    http {
    	include ${nixpkgs.mailcap}/etc/nginx/mime.types;
      include ${nixpkgs.nginx}/conf/fastcgi.conf;
      client_max_body_size 5m;
      server_tokens off;
      server {
        listen 0.0.0.0:8080;
        root /matomo;
       	location / {
          index index.php;
        }
        location = /index.php {
          fastcgi_pass ''${PHP_ADDRESS};
        }
        location = /matomo.js {
          expires 1M;
        }
        location = /matomo.php {
          fastcgi_pass ''${PHP_ADDRESS};
        }
        location = /piwik.js {
          expires 1M;
        }
        location = /piwik.php {
          fastcgi_pass ''${PHP_ADDRESS};
        }
        location = /robots.txt {
          return 200 "User-agent: *\nDisallow: /\n";
        }
        location ~ ^/(?:core|lang|misc)/ {
          return 403;
        }
        location ~* \.(?:bat|git|ini|sh|txt|tpl|xml|md)$ {
          return 403;
        }
        location ~* ^.+\.php$ {
          return 403;
        }
      }
    }
  '';
in
{
  matomoNginx = writeShellApplication {
    name = "entrypoint";
    runtimeInputs = [ nixpkgs.envsubst nixpkgs.nginx ];
    text = ''
      envsubst < ${nginxConf} > /tmp/default.conf
      nginx -c /tmp/default.conf -e /dev/stderr
    '';
  };

  matomo = writeShellApplication
    {
      name = "entrypoint";
      text = ''
        export PIWIK_USER_PATH=${dataDir};
        export MATOMO_USER_PATH=${dataDir};

        mkdir -p ${dataDir}/tmp
        chown -R matomo:matomo ${dataDir}

        chmod -R ug+rwX,o-rwx ${dataDir}
        if [ -e ${dataDir}/current-package ]; then
          CURRENT_PACKAGE=$(readlink ${dataDir}/current-package)
          NEW_PACKAGE=${nixpkgs.matomo}
          if [ "$CURRENT_PACKAGE" != "$NEW_PACKAGE" ]; then
            # keeping tmp arround between upgrades seems to bork stuff, so delete it
            rm -rf ${dataDir}/tmp
          fi
        elif [ -e ${dataDir}/tmp ]; then
          rm -rf ${dataDir}/tmp
        fi

        ln -sfT ${nixpkgs.matomo} ${dataDir}/current-package

        # Use User-Private Group scheme to protect Matomo data, but allow administration / backup via 'matomo' group
        # Copy config folder
        chmod g+s "${dataDir}"
        cp -r "${nixpkgs.matomo}/share/config" "${dataDir}/"
        mkdir -p "${dataDir}/misc"
        chmod -R u+rwX,g+rwX,o-rwx "${dataDir}"
        # check whether user setup has already been done
        if test -f "${dataDir}/config/config.ini.php"; then
          # then execute possibly pending database upgrade
          ${nixpkgs.matomo}/bin/matomo-console core:update --yes
        fi

        exec ${nixpkgs.php}/bin/php-fpm -y ${cfgFile} -c ${iniFile}
      '';
    } // {
    passthru.matomo = nixpkgs.matomo;
  };
}
