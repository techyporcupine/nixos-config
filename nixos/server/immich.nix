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
      machine-learning.enable = true;
      environment.IMMICH_MACHINE_LEARNING_URL = "http://localhost:3003";
    };
    users.users.immich.extraGroups = ["video" "render"];

    services.traefik.dynamicConfigOptions.http = {
      routers = {
        immich = {
          rule = "Host(`immich.local.cb-tech.me`)";
          service = "immich";
          entrypoints = ["websecure"];
        };
      };
      services.immich = {loadBalancer.servers = [{url = "http://localhost:2283";}];};
    };
  };
}
