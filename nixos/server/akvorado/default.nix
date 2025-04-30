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

    services.apache-kafka = {
      enable = true;
      # Replace with a randomly generated uuid. You can get one by running:
      # kafka-storage.sh random-uuid
      clusterId = "NXo1eWCSTmmUZB1fpPuzXg";
      formatLogDirs = true;
      settings = {
        listeners = [
          "PLAINTEXT://:9092"
          "CONTROLLER://:9093"
        ];
        # Adapt depending on your security constraints
        "listener.security.protocol.map" = [
          "PLAINTEXT:PLAINTEXT"
          "CONTROLLER:PLAINTEXT"
        ];
        "controller.quorum.voters" = [
          "1@127.0.0.1:9093"
        ];
        "controller.listener.names" = ["CONTROLLER"];

        "node.id" = 1;
        "process.roles" = ["broker" "controller"];

        # I prefer to use this directory, because /tmp may be erased
        "log.dirs" = ["/var/lib/apache-kafka"];
        "offsets.topic.replication.factor" = 1;
        "transaction.state.log.replication.factor" = 1;
        "transaction.state.log.min.isr" = 1;
      };
    };

    # Set this so that systemd automatically create /var/lib/apache-kafka
    # with the right permissions
    systemd.services.apache-kafka.unitConfig.StateDirectory = "apache-kafka";

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
