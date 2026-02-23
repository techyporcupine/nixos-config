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
        jellyfinext = {
          rule = "Host(`jellyfin.cb-tech.me`)";
          service = "jellyfin";
          entrypoints = ["websecure"];
          tls.domains = [{main = "jellyfin.cb-tech.me";}];
          tls.certResolver = "cloudflare";
        };
      };
      services.jellyfin = {loadBalancer.servers = [{url = "http://localhost:8096";}];};
    };
    networking.firewall = {
      interfaces."ens18" = {
        allowedTCPPorts = [
          8096
        ];
      };
    };
  };
}
