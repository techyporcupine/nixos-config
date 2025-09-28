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
    server.enable = lib.mkEnableOption "Enable Beszel server";
    client.enable = lib.mkEnableOption "Enable Beszel client service";
    client.sshKey = lib.mkOption {
      type = with lib.types; nullOr str; # FIXME: setting this to null may break things
      default = null;
      description = "The SSH key to use as given by Beszel UI";
    };
    client.extraFilesystens = lib.mkOption {
      type = with lib.types; nullOr str; # FIXME: setting this to null may break things
      default = null;
      description = "Path to any extra filesystems to monitor";
    };
  };
  config = {
    virtualisation.oci-containers.containers = lib.mkIf cfg.server.enable {
      beszel = {
        volumes = ["/home/${config.tp.username}/beszel_data:/beszel_data"];
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
    services.traefik.dynamicConfigOptions.http = lib.mkIf cfg.server.enable {
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

    systemd.services.beszel = lib.mkIf cfg.client.enable {
      enable = true;
      path = [pkgs.beszel];
      serviceConfig = {
        ExecStart = "${pkgs.beszel}/bin/beszel-agent";
      };
      environment = {
        LISTEN = "45876";
        KEY = "${config.tp.server.beszel.sshKey}";
        EXTRA_FILESYSTEMS = lib.mkIf (config.tp.server.beszel.client.extraFilesystems != null) "${config.tp.server.beszel.client.extraFilesystens}";
      };
      unitConfig = {
        Type = "simple";
      };
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      requires = ["network-online.target"];
    };
    networking.firewall = lib.mkIf cfg.client.enable {
      allowedTCPPorts = [
        45876
      ];
    };
  };
}
