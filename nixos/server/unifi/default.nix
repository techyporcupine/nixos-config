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
      unifiPackage = pkgs.unifi;
      mongodbPackage = pkgs.stable.mongodb;
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
          middlewares = ["internal-whitelist"];
          tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
          tls.certResolver = "cloudflare";
        };
      };
      services.unifi = {loadBalancer.servers = [{url = "https://localhost:8443/";}];};
    };
  };
}
