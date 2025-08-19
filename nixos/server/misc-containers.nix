{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.virtualisation;
in {
  options.tp.server.virtualisation = {
    enable = lib.mkEnableOption "Enable Virtualization";
    containers.enable = lib.mkEnableOption "Enable containers";
  };

  config = lib.mkIf cfg.enable {
    virtualisation = {
      podman = {
        enable = true;

        # Create a `docker` alias for podman, to use it as a drop-in replacement
        dockerCompat = true;

        # Required for containers under podman-compose to be able to talk to each other.
        defaultNetwork.settings.dns_enabled = true;
      };
      oci-containers = lib.mkIf cfg.containers.enable {
        backend = "podman";
        containers = {
          dashy = {
            image = "lissy93/dashy:latest";
            volumes = ["/home/${config.tp.username}/dashy:/app/user-data"];
            autoStart = true;
            extraOptions = [
              "--pull=newer" # Pull if the image on the registry is newer than the one in the local containers storage
            ];
            ports = ["127.0.0.1:18080:8080"];
          };
          openspeedtest = {
            image = "openspeedtest/latest";
            autoStart = true;
            extraOptions = [
              "--pull=newer" # Pull if the image on the registry is newer than the one in the local containers storage
            ];
            ports = ["0.0.0.0:13002:3000"];
          };
          librespeed = {
            image = "ghcr.io/librespeed/speedtest:latest";
            autoStart = true;
            environment = {
              MODE = "standalone";
              TITLE = "Librespeed";
            };
            extraOptions = [
              "--pull=newer" # Pull if the image on the registry is newer than the one in the local containers storage
            ];
            ports = ["127.0.0.1:13003:80"];
          };
          rtlamr = {
            image = "allangood/rtlamr2mqtt";
            volumes = ["/home/${config.tp.username}/rtlamr/rtlamr2mqtt.yaml:/etc/rtlamr2mqtt.yaml"];
            autoStart = true;
            extraOptions = [
              "--pull=newer" # Pull if the image on the registry is newer than the one in the local containers storage
              "--device=/dev/bus/usb/005/005:/dev/bus/usb/005/005"
            ];
          };
        };
      };
    };
  };
}
