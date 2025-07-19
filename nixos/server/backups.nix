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
            "/home/${config.tp.username}/dashy"
            "/home/${config.tp.username}/hass"
            "/var/lib/unifi/data/backup/autobackup"
            "/srv/minecraft/broccoli-bloc/"
            "/var/lib/immich"
            "/var/lib/uptime-kuma"
            "/home/${config.tp.username}/beszel_data"
            "/var/media"
            "/var/lib/matrix-synapse"
          ];
          exclude = [
            "/var/lib/immich/encoded-video"
            "/var/lib/immich/thumbs"
          ];
          # Access via `restic -r "rest:http://helium:8000/remotebackup-large" snapshots`
          repository = "rest:http://172.16.0.6:8000/remotebackup-large";
          pruneOpts = [
            "--keep-daily 3"
            "--keep-weekly 12"
          ];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
          };
        };
      };
      server = lib.mkIf cfg.server.enable {
        enable = true;
        extraFlags = ["--no-auth"];
        dataDir = "/mnt/1TB_Backup/restic";
        #listenAddress = "100.64.0.6:8000";
        prometheus = true;
      };
    };
  };
}
