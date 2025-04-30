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

    systemd.services.akvorado-orchestrator = {
      description = "Akvorado Flow Collector Orchestrator";
      after = ["network.target" "remote-fs.target"];
      requires = ["network.target" "remote-fs.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStart = "${akvoradoPkg}/bin/akvorado orchestrator /var/lib/akvorado-orchestrator/config.yaml";
        Restart = "always";
        DynamicUser = true;
        StateDirectory = "akvorado-orchestrator";
        WorkingDirectory = "/var/lib/akvorado-orchestrator";
      };
    };
    systemd.services.akvorado-inlet = {
      description = "Akvorado Flow Collector Inlet";
      after = ["network.target" "remote-fs.target"];
      requires = ["network.target" "remote-fs.target" "akvorado-orchestrator.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStart = "${akvoradoPkg}/bin/akvorado inlet http://127.0.0.1:8083";
        Restart = "always";
        DynamicUser = true;
        StateDirectory = "akvorado-inlet";
        WorkingDirectory = "/var/lib/akvorado-inlet";
      };
    };
    systemd.services.akvorado-console = {
      description = "Akvorado Flow Collector Console";
      after = ["network.target" "remote-fs.target"];
      requires = ["network.target" "remote-fs.target" "akvorado-orchestrator.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStart = "${akvoradoPkg}/bin/akvorado console http://127.0.0.1:8082";
        Restart = "always";
        DynamicUser = true;
        StateDirectory = "akvorado-console";
        WorkingDirectory = "/var/lib/akvorado-console";
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
      services.akvorado = {loadBalancer.servers = [{url = "http://localhost:8082";}];};
    };
  };
}
