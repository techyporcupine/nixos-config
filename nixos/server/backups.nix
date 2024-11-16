{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.backups;
in {
  options.tp.server.backups = {
    enable = lib.mkEnableOption "Enable Restic backups";
  };
  # TODO: HIGHLY BROKEN
  config = lib.mkIf cfg.enable {
    services.restic = {
      backups = {
        #localbackup-small = {
        #  passwordFile = /run/secrets/restic-password;
        #  initialize = true;
        #  paths = [
        #    "/var/lib/vaultwarden/backups"
        #    "/home/bowman4/dashy"
        #    "/var/lib/hass/backups"
        #    "/var/lib/unifi/data/backup/autobackup"
        #    "/srv/minecraft/broccoli-bloc/"
        #  ];
        #  repository = "/home/bowman4/resticbackups";
        #  timerConfig = {
        #    OnCalendar = "daily";
        #    Persistent = true;
        #    RandomizedDelaySec = "10min";
        #  };
        #};
        remotebackup-large = {
          passwordFile = /var/secrets/restic-password;
          initialize = true;
          paths = [
            "/var/lib/vaultwarden/backups"
            "/home/beryllium/dashy"
            "/var/lib/hass/"
            "/var/lib/unifi/data/backup/autobackup"
            "/srv/minecraft/broccoli-bloc/"
          ];
          repository = "rest:http://100.64.0.6:8000/remotebackup-large";
          pruneOpts = [
            "--keep-daily 3"
            "--keep-weekly 24"
          ];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "10min";
          };
        };
      };
    };
  };
}
