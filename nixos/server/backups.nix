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
    client.enable = lib.mkEnableOption "Enable Restic client backups";
    server.enable = lib.mkEnableOption "Enable Restic REST server";
  };
  # TODO: HIGHLY BROKEN
  config = {
    services.restic = {
      backups = lib.mkIf cfg.client.enable {
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
          passwordFile = "/var/secrets/restic-password";
          initialize = true;
          paths = [
            "/var/backup/vaultwarden"
            "/home/beryllium/dashy"
            "/home/beryllium/hass"
            "/var/lib/unifi/data/backup/autobackup"
            "/srv/minecraft/broccoli-bloc/"
            "/var/lib/immich"
          ];
          exclude = [
            "/var/lib/immich/encoded-video"
            "/var/lib/immich/thumbs"
          ];
          # Access via `restic -r "rest:http://helium:8000/remotebackup-large" snapshots`
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
      server = lib.mkIf cfg.server.enable {
        enable = true;
        extraFlags = ["--no-auth"];
        dataDir = "/mnt/1TB_Backup/restic";
      };
    };
  };
}
