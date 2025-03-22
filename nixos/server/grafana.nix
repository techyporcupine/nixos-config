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
      domain = "grafana.local.cb-tech.me";
      port = 2342;
      addr = "127.0.0.1";
    };
    services.prometheus = {
      enable = true;
      port = 9111;
      scrapeConfigs = [
        {
          job_name = "opnsense";
          static_configs = [
            {
              targets = ["10.0.0.1:9100"];
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
