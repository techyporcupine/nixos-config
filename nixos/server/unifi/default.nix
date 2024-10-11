{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.unifi;
in {
  options.tp.server.unifi = {
    enable = lib.mkEnableOption "Enable Unifi Controller";
  };

  config = lib.mkIf cfg.enable {
    services.unifi = {
      enable = true;
      # open default firewall ports
      openFirewall = true;
      # use latest unifi package
      unifiPackage = pkgs.unifiCustom;
      mongodbPackage = pkgs.mongodb-6_0;
    };

    nixpkgs.overlays = [
      (import ./unifi-overlay.nix)
    ];

    services.traefik.dynamicConfigOptions.http = {
      routers = {
        unifi = {
          rule = "Host(`unifi.local.cb-tech.me`)";
          service = "unifi";
          entrypoints = ["websecure"];
        };
      };
      services.unifi = {loadBalancer.servers = [{url = "https://localhost:8443/";}];};
    };
  };
}
