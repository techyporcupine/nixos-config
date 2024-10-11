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
          wishthis = {
            image = "hiob/wishthis:release-candidate";
            volumes = ["/home/${config.tp.username}/wishthis/config.php:/var/www/html/src/config/config.php"];
            autoStart = true;
            environment = {
              VIRTUAL_HOST = "wish.cb-tech.me";
            };
            extraOptions = [
              "--pull=newer" # Pull if the image on the registry is newer than the one in the local containers storage
              "--network=wishthis"
            ];
            ports = ["127.0.0.1:18022:80"];
          };
          mariadb = {
            image = "mariadb";
            volumes = ["/home/${config.tp.username}/wishthis/mariadb:/var/lib/mysql"];
            environmentFiles = ["/var/secrets/wishthis"];
            autoStart = true;
            extraOptions = [
              "--pull=newer" # Pull if the image on the registry is newer than the one in the local containers storage
              "--network=wishthis"
            ];
            ports = ["127.0.0.1:3306:3306"];
          };
        };
      };
    };
  };
}
