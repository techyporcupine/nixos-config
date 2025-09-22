{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.tp.server.llama-swap;
in {
  options.tp.server = {
    llama-swap.enable = lib.mkEnableOption "Enable llama-swap";
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [5349];

    users.users.${config.tp.username}.linger = true;

    systemd.user.services.llama-swap = {
      enable = true;
      description = "llama-swap for managing llama.cpp models";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.llama-swap}/bin/llama-swap -config %E/llama-swap/llama-swap.yaml -listen 0.0.0.0:5349";
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    tp.hm.xdg.configFile = {
      "llama-swap.yaml" = {
        enable = true;
        source = ./${config.networking.hostName}-llama-swap.yaml;
        target = "llama-swap/llama-swap.yaml";
      };
    };
  };
}
