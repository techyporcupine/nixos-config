{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.jellyfin;
in {
  options.tp.server.jellyfin = {
    enable = lib.mkEnableOption "Enable jellyfin";
  };

  config = lib.mkIf cfg.enable {
    services.jellyfin = {
      enable = true;
    };
    services.traefik.dynamicConfigOptions.http = {
      routers = {
        jellyfin = {
          rule = "Host(`jellyfin.local.cb-tech.me`)";
          service = "jellyfin";
          entrypoints = ["websecure"];
          middlewares = ["internal-whitelist"];
          tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
          tls.certResolver = "cloudflare";
        };
      };
      services.jellyfin = {loadBalancer.servers = [{url = "http://localhost:8096";}];};
    };
  };
}
