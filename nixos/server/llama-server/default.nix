{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.tp.server.llama-server;
in {
  options.tp.server = {
    llama-server = {
      enable = lib.mkEnableOption "Enable llama-server router";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.llama-cpp;
        description = "The llama-cpp package to use.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [5349];

    users.users.${config.tp.username}.linger = true;

    systemd.user.services.llama-server = {
      enable = true;
      description = "llama-server router for managing llama.cpp models";
      after = ["network.target"];
      wantedBy = ["default.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/llama-server --models-preset %E/llama-cpp/models.ini --host 0.0.0.0 --port 5349 --models-max 1";
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    tp.hm.xdg.configFile = {
      "llama-models.ini" = {
        enable = true;
        source = config.tp.hm.lib.file.mkOutOfStoreSymlink "${config.tp.hm.home.homeDirectory}/nixos-config/nixos/server/llama-server/${config.networking.hostName}-models.ini";
        target = "llama-cpp/models.ini";
      };
    };
  };
}
