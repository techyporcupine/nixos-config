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
      matter-hub = {
        volumes = ["/home/${config.tp.username}/matter-hub:/data"];
        image = "ghcr.io/t0bst4r/home-assistant-matter-hub:latest"; # Warning: if the tag does not change, the image will not be updated
        extraOptions = [
          "--network=host"
          "--pull=newer"
        ];
        environmentFiles = [/var/secrets/matter-hub];
      };
    };
    services.wyoming = {
      piper.servers.hasspiper = {
        enable = true;
        uri = "tcp://0.0.0.0:10200";
        voice = "en-us-ryan-high";
      };
      faster-whisper.servers.hasswhisper = {
        enable = true;
        device = "cpu";
        uri = "tcp://0.0.0.0:10300";
        model = "Systran/faster-distil-whisper-medium.en";
        language = "en";
      };
    };
    services.matter-server = {
      enable = true;
    };
    services.mosquitto = {
      enable = true;
      listeners = [
        {
          address = "0.0.0.0";
          acl = ["pattern readwrite #"];
          omitPasswordAuth = true;
          settings.allow_anonymous = true;
        }
      ];
    };
    services.zigbee2mqtt = {
      enable = true;
      package = pkgs.stable.master.zigbee2mqtt;
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
          transmit_power = 10;
          channel = 26;
        };
        availability = true;
      };
    };
    environment.systemPackages = with pkgs; [
      net-snmp
    ];
    services.traefik.dynamicConfigOptions.http = {
      routers = {
        homeassistantext = {
          rule = "Host(`home.cb-tech.me`)";
          service = "homeassistant";
          entrypoints = ["websecure"];
          tls.domains = [{main = "home.cb-tech.me";}];
          tls.certResolver = "cloudflare";
        };
        z2m = {
          rule = "Host(`z2m.local.cb-tech.me`)";
          service = "z2m";
          entrypoints = ["websecure"];
          middlewares = ["internal-whitelist"];
          tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
          tls.certResolver = "cloudflare";
        };
        matter = {
          rule = "Host(`matter.local.cb-tech.me`)";
          service = "matter";
          entrypoints = ["websecure"];
          middlewares = ["internal-whitelist"];
          tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
          tls.certResolver = "cloudflare";
        };
      };
      services.homeassistant = {loadBalancer.servers = [{url = "http://localhost:8124";}];};
      services.z2m = {loadBalancer.servers = [{url = "http://localhost:8091";}];};
      services.matter = {loadBalancer.servers = [{url = "http://localhost:8482";}];};
    };
    networking.firewall = {
      allowedTCPPorts = [
        1883
      ];
      interfaces."ens18" = {
        allowedTCPPorts = [
          # Homekit
          51827
          # Z2M
          8091
          # Matter
          5540
        ];
        allowedUDPPorts = [
          # Homekit
          5353
          # Matter
          5540
        ];
      };
      interfaces."vlan124" = {
        allowedTCPPorts = [
          # Homekit
          51827
          # Matter
          8482
          5540
        ];
        allowedUDPPorts = [
          # Homekit
          5353
          # Matter
          5540
        ];
      };
    };
  };
}
