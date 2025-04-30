{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.grafana;
in {
  options.tp.server.grafana = {
    enable = lib.mkEnableOption "Enable grafana and prometheus";
  };

  config = lib.mkIf cfg.enable {
    services.grafana = {
      enable = true;
      settings.server = {
        domain = "grafana.local.cb-tech.me";
        http_port = 2342;
        addr = "127.0.0.1";
      };
    };
    services.prometheus = {
      enable = true;
      port = 9111;
      exporters = {
        snmp = {
          enable = true;
          openFirewall = true;
          configuration = {
            auths = {
              public_v2 = {
                community = "public";
                version = 2;
              };
            };
            modules = {
              ubiquiti_unifi = {
                walk = ["1.3.6.1.4.1.41112.1.6"];
              };
            };
          };
        };
      };
      scrapeConfigs = [
        {
          job_name = "opnsense-bowman4";
          static_configs = [
            {
              targets = ["10.0.0.1:9100"];
            }
          ];
        }
        {
          job_name = "restic-prometheus";
          static_configs = [
            {
              targets = ["100.64.0.6:8000"];
            }
          ];
        }
        {
          job_name = "pushgateway";
          scrape_interval = "300s";
          honor_labels = true;
          static_configs = [
            {
              targets = ["127.0.0.1:9091"];
            }
          ];
        }
      ];
    };
    services.traefik.dynamicConfigOptions.http = {
      routers = {
        grafana = {
          rule = "Host(`grafana.local.cb-tech.me`)";
          service = "grafana";
          entrypoints = ["websecure"];
          middlewares = ["internal-whitelist"];
          tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
          tls.certResolver = "cloudflare";
        };
      };
      services.grafana = {loadBalancer.servers = [{url = "http://localhost:2342";}];};
    };
  };
}
