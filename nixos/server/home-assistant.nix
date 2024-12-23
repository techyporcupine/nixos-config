{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.home-assistant;
in {
  options.tp.server.home-assistant = {
    enable = lib.mkEnableOption "Enable Home Assistant";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers = {
      homeassistant = {
        volumes = ["/home/${config.tp.username}/hass:/config" "/run/dbus:/run/dbus:ro"];
        environment.TZ = "America/New_York";
        image = "ghcr.io/home-assistant/home-assistant:stable"; # Warning: if the tag does not change, the image will not be updated
        extraOptions = [
          "--network=host"
          "--pull=newer"
        ];
      };
    };
    services.wyoming = {
      piper.servers.hasspiper = {
        enable = true;
        uri = "tcp://0.0.0.0:10200";
        voice = "en-us-ryan-high";
      };
    };
    services.traefik.dynamicConfigOptions.http = {
      routers = {
        homeassistantext = {
          rule = "Host(`home.cb-tech.me`)";
          service = "homeassistant";
          entrypoints = ["websecure"];
          tls.domains = [{main = "home.cb-tech.me";}];
          tls.certResolver = "cloudflare";
        };
      };
      services.homeassistant = {loadBalancer.servers = [{url = "http://localhost:8124";}];};
    };
    networking.firewall = {
      allowedTCPPorts = [
        # Homekit
        51827
      ];
      allowedUDPPorts = [
        # Homekit
        5353
      ];
    };
  };
}
