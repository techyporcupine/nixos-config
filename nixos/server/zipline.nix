{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.zipline;
in {
  options.tp.server.zipline = {
    enable = lib.mkEnableOption "Enable zipline";
  };

  config = lib.mkIf cfg.enable {
    services.zipline = {
      enable = true;
      settings = {
        CORE_HOSTNAME = "0.0.0.0";
        CORE_PORT = 3000;
        FEATURES_THUMBNAILS_NUM_THREADS = "4";
        FEATURES_OAUTH_REGISTRATION = true;
      };
      environmentFiles = ["/var/secrets/zipline.env"];
    };
    networking.firewall = {
      allowedTCPPorts = [
        3000
      ];
    };
  };
}
