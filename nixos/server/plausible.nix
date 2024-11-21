{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.plausible;
in {
  options.tp.server.plausible = {
    enable = lib.mkEnableOption "Enable Plausible";
  };

  config = lib.mkIf cfg.enable {
    services.plausible = {
      enable = true;
      adminUser = {
        # activate is used to skip the email verification of the admin-user that's
        # automatically created by plausible. This is only supported if
        # postgresql is configured by the module. This is done by default, but
        # can be turned off with services.plausible.database.postgres.setup.
        activate = true;
        email = "admin@localhost";
        passwordFile = "/var/secrets/plausible-admin-password";
      };
      server = {
        baseUrl = "https://plaus.cb-tech.me";
        port = 18002;
        # secretKeybaseFile is a path to the file which contains the secret generated
        # with openssl as described above.
        secretKeybaseFile = "/var/secrets/plausible-secret-key";
      };
    };
    #services.traefik.dynamicConfigOptions.http = {
    #routers = {
    #  plausible = {
    #    rule = "Host(`plaus.cb-tech.me`)";
    #    service = "plausible";
    #    entrypoints = ["websecure"];
    #    tls.domains = [{main = "plaus.cb-tech.me";}];
    #    tls.certResolver = "cloudflare";
    #  };
    #};
    #services.plausible = {loadBalancer.servers = [{url = "http://localhost:18002";}];};
    #};
  };
}
