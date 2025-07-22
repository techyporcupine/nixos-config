##### WARNING!!!  #####
### THIS IS A STUB  ###
# IS NOT SET UP FULLY #
#######################
{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.authelia;
in {
  options.tp.server.authelia = {
    enable = lib.mkEnableOption "Enable authelia";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers = {
      homeassistant = {
        volumes = ["/home/${config.tp.username}/authelia/config:/config"];
        image = "authelia/authelia:latest"; # Warning: if the tag does not change, the image will not be updated
        extraOptions = [
          "--pull=newer"
        ];
        ports = ["127.0.0.1:9091:9091"];
      };
    };

    services.traefik.dynamicConfigOptions.http = {
      routers = {
        authelia = {
          rule = "Host(`auth.cb-tech.me`)";
          service = "authelia";
          entrypoints = ["websecure"];
          middlewares = ["authelia"];
          tls.domains = [{main = "auth.cb-tech.me";}];
          tls.certResolver = "cloudflare";
        };
      };
      services.authelia = {loadBalancer.servers = [{url = "http://localhost:9091";}];};
    };
  };
}
