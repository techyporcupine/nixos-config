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
      openthread = {
        volumes = ["/dev/ttyUSB1:/dev/ttyUSB1"];
        image = "openthread/otbr"; # Warning: if the tag does not change, the image will not be updated
        ports = ["127.0.0.1:8092:8080"];
        extraOptions = [
          #"--sysctl 'net.ipv6.conf.all.disable_ipv6=0 net.ipv4.conf.all.forwarding=1 net.ipv6.conf.all.forwarding=1'"
          "--dns=127.0.0.1"
          "-it"
          "--privileged"
          "--radio-url spinel+hdlc+uart:///dev/ttyUSB1"
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
    services.matter-server = {
      enable = true;
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
        homeassistant = true;
        serial = {
          port = "/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_24d5aba9cb12ef1183936db8bf9df066-if00-port0";
          adapter = "ember";
        };
        mqtt = {
          server = "mqtt://localhost:1883";
        };
        frontend = {
          port = 8091;
        };
        advanced = {
          transmit_power = 5;
          channel = 26;
        };
        availability = true;
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
