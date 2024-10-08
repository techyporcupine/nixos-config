{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.uptime-kuma;
in {
  options.tp.server.uptime-kuma = {
    enable = lib.mkEnableOption "Enable Uptime Kuma";
  };

  config = lib.mkIf cfg.enable {
    services.uptime-kuma = {
      enable = true;
      settings = {
        PORT = "13001";
        UPTIME_KUMA_DISABLE_FRAME_SAMEORIGIN = "1";
      };
    };
    services.traefik.dynamicConfigOptions.http = {
      routers = {
        uptimekuma = {
          rule = "Host(`uptime.local.cb-tech.me`)";
          service = "uptimekuma";
          entrypoints = ["websecure"];
        };
        uptimemc = {
          rule = "Host(`status.mc.cb-tech.me`)";
          service = "uptimemc";
          entrypoints = ["externalwebsecure" "websecure"];
          tls.domains = [{main = "status.mc.cb-tech.me";}];
          tls.certResolver = "cloudflare";
        };
      };
      services.uptimekuma = {loadBalancer.servers = [{url = "http://localhost:${toString config.services.uptime-kuma.settings.PORT}";}];};
      services.uptimemc = {loadBalancer.servers = [{url = "http://localhost:${toString config.services.uptime-kuma.settings.PORT}";}];};
    };
  };
}
