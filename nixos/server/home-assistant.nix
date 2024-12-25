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
          #"--device=/dev/ttyUSB0"
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
    services.mosquitto = {
      enable = true;
      listeners = [
        {
          acl = ["pattern readwrite #"];
          omitPasswordAuth = true;
          settings.allow_anonymous = true;
        }
      ];
    };
    services.zigbee2mqtt = {
      enable = true;
      settings = {
        homeassistant = config.services.home-assistant.enable;
        permit_join = true;
        serial = {
          port = "/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_24d5aba9cb12ef1183936db8bf9df066-if00-port0";
          adapter = "ember";
        };
        mqtt = {
          server = "mqtt://localhost:1883";
        };
        frontend.port = 8091;
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
        # MQTT
        1883
        # Z2M
        8091
      ];
      allowedUDPPorts = [
        # Homekit
        5353
      ];
    };
  };
}
