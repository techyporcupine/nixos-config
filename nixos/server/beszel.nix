{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.beszel;
in {
  options.tp.server.beszel = {
    enable = lib.mkEnableOption "Enable Beszel";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers = {
      beszel = {
        volumes = ["/home/${config.tp.username}/beszel_data:/config"];
        image = " docker.io/henrygd/beszel"; # Warning: if the tag does not change, the image will not be updated
        ports = [
          "127.0.0.1:8090:8090"
        ];
        extraOptions = [
          "--pull=newer"
          #"--device=/dev/ttyUSB0"
        ];
      };
    };
    services.traefik.dynamicConfigOptions.http = {
      routers = {
        beszel = {
          rule = "Host(`hosts.local.cb-tech.me`)";
          service = "beszel";
          entrypoints = ["websecure"];
          middlewares = ["internal-whitelist"];
          tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
          tls.certResolver = "cloudflare";
        };
      };
      services.beszel = {loadBalancer.servers = [{url = "http://localhost:8090";}];};
    };
  };
}
