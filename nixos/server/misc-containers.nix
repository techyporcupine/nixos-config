{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.containers;
in {
  options.tp.server.containers = {
    enable = lib.mkEnableOption "Enable Containers";
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
      oci-containers = {
        backend = "podman";
        containers = {
          dashy = {
            image = "lissy93/dashy:latest";
            volumes = ["/home/bowman4/dashy:/app/user-data"];
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
            ports = ["127.0.0.1:13002:3000"];
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
          zap2xml = {
            image = "shuaiscott/zap2xml";
            volumes = ["/mnt/NixServeStorage/Data/Jellyfin:/data"];
            autoStart = true;
            environment = {
              XMLTV_FILENAME = "xmltv.xml";
              OPT_ARGS = "-I -D";
            };
            environmentFiles = ["/run/secrets/zap2xml"];
            extraOptions = [
              "--pull=newer" # Pull if the image on the registry is newer than the one in the local containers storage
            ];
          };
        };
      };
    };
  };
}
