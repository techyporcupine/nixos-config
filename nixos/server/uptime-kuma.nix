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
          middlewares = ["internal-whitelist"];
          tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
          tls.certResolver = "cloudflare";
        };
      };
      services.uptimekuma = {loadBalancer.servers = [{url = "http://localhost:${toString config.services.uptime-kuma.settings.PORT}";}];};
    };
  };
}
