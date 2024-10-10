{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.vaultwarden;
in {
  options.tp.server.vaultwarden = {
    enable = lib.mkEnableOption "Enable Vaultwarden";
  };

  config = lib.mkIf cfg.enable {
    services.vaultwarden = {
      enable = true;
      backupDir = "/var/backup/vaultwarden";
      environmentFile = /run/secrets/vaultwarden-env;
      config = {
        DOMAIN = "https://vault.cb-tech.me";
        SIGNUPS_ALLOWED = false;

        ROCKET_ADDRESS = "::1";
        ROCKET_PORT = 18222;
      };
    };
    services.traefik.dynamicConfigOptions.http = {
      routers = {
        vaultwarden = {
          rule = "Host(`vault.cb-tech.me`)";
          service = "vaultwarden";
          entrypoints = ["externalwebsecure" "websecure"];
          tls.domains = [{main = "vault.cb-tech.me";}];
          tls.certResolver = "cloudflare";
        };
      };
      services.vaultwarden = {loadBalancer.servers = [{url = "http://localhost:${toString config.services.vaultwarden.config.ROCKET_PORT}";}];};
    };
  };
}
