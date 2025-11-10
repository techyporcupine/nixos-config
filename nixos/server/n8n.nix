{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.n8n;
in {
  options.tp.server.n8n = {
    enable = lib.mkEnableOption "Enable n8n";
  };

  config = lib.mkIf cfg.enable {
    services.n8n = {
      enable = true;
      webhookUrl = "https://n8n.cb-tech.me/";
    };
    services.traefik.dynamicConfigOptions.http = {
      routers = {
        n8n = {
          rule = "Host(`n8n.cb-tech.me`)";
          service = "n8n";
          entrypoints = ["websecure"];
          tls.domains = [{main = "n8n.cb-tech.me";}];
          tls.certResolver = "cloudflare";
        };
      };
      services.n8n = {loadBalancer.servers = [{url = "http://localhost:5678";}];};
    };
  };
}
