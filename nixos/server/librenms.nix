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
        passwordFile = "/var/secrets/librenmsdb";
      };

      nginx = {
        virtualHosts = {
          "librenms.internal" = {
            root = "/var/www/librenms/html";
            listen = [
              {
                addr = "127.0.0.1";
                port = 18089;
              }
            ];
            locations."/" = {
              index = "index.php";
            };
          };
        };
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
