{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.immich;
in {
  options.tp.server.immich = {
    enable = lib.mkEnableOption "Enable Immich";
  };

  config = lib.mkIf cfg.enable {
    services.immich = {
      enable = true;
      package = pkgs.immich;
      machine-learning.enable = true;
      environment.IMMICH_MACHINE_LEARNING_URL = "http://localhost:3003";
    };
    users.users.immich.extraGroups = ["video" "render"];

    services.traefik.dynamicConfigOptions.http = {
      routers = {
        immich = {
          rule = "Host(`immich.cb-tech.me`)";
          service = "immich";
          entrypoints = ["websecure"];
          tls.domains = [{main = "immich.cb-tech.me";}];
          tls.certResolver = "cloudflare";
        };
      };
      services.immich = {loadBalancer.servers = [{url = "http://localhost:2283";}];};
    };
  };
}
