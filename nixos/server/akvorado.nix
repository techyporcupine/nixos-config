{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.akvorado;
  akvoradoPkg = inputs.akvorado.packages.${pkgs.system}.default;
in {
  options.tp.server.akvorado = {
    enable = lib.mkEnableOption "Enable Akvorado and dependencies";
  };

  config = lib.mkIf cfg.enable {
    services.clickhouse.enable = true;

    services.apache-kafka.enable = true;

    systemd.services.akvorado = {
      description = "Akvorado Flow Collector";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStart = "${akvoradoPkg}/bin/akvorado";
        Restart = "always";
        DynamicUser = true;
        StateDirectory = "akvorado";
        WorkingDirectory = "/var/lib/akvorado";
      };
    };

    services.traefik.dynamicConfigOptions.http = {
      routers = {
        akvorado = {
          rule = "Host(`akvorado.local.cb-tech.me`)";
          service = "akvorado";
          entrypoints = ["websecure"];
          middlewares = ["internal-whitelist"];
          tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
          tls.certResolver = "cloudflare";
        };
      };
      services.akvorado = {loadBalancer.servers = [{url = "http://localhost:8081";}];};
    };
  };
}
