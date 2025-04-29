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
        # Configure the listener (maps to 'listen' directive)
        listen = [
          {
            addr = "127.0.0.1"; # Listen only on localhost
            port = 18089; # The port Traefik forwards to
          }
        ];

        # Set the document root (maps to 'root' directive)
        # Use the package path for robustness
        # root = "${config.services.librenms.package}/html";

        # Configure locations (maps to 'location' blocks)
        locations."/" = {
          # Add the try_files directive for PHP routing
          tryFiles = "$uri $uri/ /index.php?$query_string";

          # Set the index file
          index = "index.php";
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
