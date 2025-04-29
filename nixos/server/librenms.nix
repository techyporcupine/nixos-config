{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.tp.server.librenms;
in {
  options.tp.server.librenms = {
    enable = lib.mkEnableOption "Enable LibreNMS network monitoring system";
  };

  config = lib.mkIf cfg.enable {
    # LibreNMS setup with local DB
    services.librenms = {
      enable = true;

      database = {
        createLocally = true;
        passwordFile = /run/secrets/librenmsdb;
      };
    };

    # nginx listens only locally, Traefik proxies it
    services.nginx.virtualHosts."librenms.internal" = {
      root = "/var/www/librenms/html";
      listen = [
        {
          addr = "127.0.0.1";
          port = 18089;
        }
      ];
      locations."/" = {
        index = "index.php";
        tryFiles = "$uri $uri/ /index.php?$query_string";
      };
      locations."~ \.php$" = {
        fastcgiPass = "unix:/run/phpfpm/librenms.sock";
        fastcgiIndex = "index.php";
        extraConfig = ''
          include fastcgi.conf;
        '';
      };
    };

    # PHP-FPM pool
    services.phpfpm.pools.librenms = {
      user = "librenms";
      group = "librenms";
      phpPackage = pkgs.php;
      settings = {
        "listen" = "/run/phpfpm/librenms.sock";
        "listen.owner" = "librenms";
        "listen.group" = "nginx";
        "listen.mode" = "0660";
      };
    };

    # Traefik reverse proxy to nginx
    services.traefik.dynamicConfigOptions.http = {
      routers = {
        librenms = {
          rule = "Host(`librenms.local.cb-tech.me`)";
          service = "librenms";
          entrypoints = ["websecure"];
          middlewares = ["internal-whitelist"];
          tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
          tls.certResolver = "cloudflare";
        };
      };
      services.librenms = {loadBalancer.servers = [{url = "http://localhost:18089";}];};
    };
  };
}
