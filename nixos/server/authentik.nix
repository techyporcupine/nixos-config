{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.authentik;
in {
  options.tp.server.authentik = {
    enable = lib.mkEnableOption "Enable authentik reverse proxy";
  };

  config = lib.mkIf cfg.enable {
    services.traefik.dynamicConfigOptions.http = {
      routers = {
        authentik = {
          rule = "Host(`auth.cb-tech.me`)";
          service = "authentik";
          entrypoints = ["websecure"];
          tls.domains = [{main = "auth.cb-tech.me";}];
          tls.certResolver = "cloudflare";
        };
      };
      services.authentik = {loadBalancer.servers = [{url = "http://10.0.0.12:9000";}];};
    };
  };
}
