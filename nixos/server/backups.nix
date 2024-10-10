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
        localbackup-small = {
          passwordFile = /run/secrets/restic-password;
          initialize = true;
          paths = [
            "/var/lib/vaultwarden/backups"
            "/home/bowman4/dashy"
            "/var/lib/hass/backups"
            "/var/lib/unifi/data/backup/autobackup"
            "/home/bowman4/.config/sops/age/"
            "/srv/minecraft/broccoli-bloc/"
          ];
          repository = "/home/bowman4/resticbackups";
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "10min";
          };
        };
        cloudbackup-small = {
          passwordFile = config.sops.secrets.restic-password.path;
          environmentFile = config.sops.secrets.restic-r2-env.path;
          initialize = true;
          paths = [
            "/var/lib/vaultwarden/backups"
            "/home/bowman4/dashy"
            "/var/lib/hass/backups"
            "/var/lib/unifi/data/backup/autobackup"
            "/home/bowman4/.config/sops/age/"
          ];
          repository = "s3:https://6a8bb05e266bab6f4eee1fc6717f432a.r2.cloudflarestorage.com/tp-r2";
          timerConfig = {
            OnCalendar = "weekly";
            Persistent = true;
            RandomizedDelaySec = "10min";
          };
        };
        remotebackup-small = {
          passwordFile = config.sops.secrets.restic-password.path;
          initialize = true;
          extraOptions = [
            "sftp.command='ssh bowman4@100.64.0.6 -i /home/bowman4/.ssh/id_ed25519 -s sftp'"
          ];
          paths = [
            "/var/lib/vaultwarden/backups"
            "/home/bowman4/dashy"
            "/var/lib/hass/backups"
            "/var/lib/unifi/data/backup/autobackup"
            "/home/bowman4/.config/sops/age/"
            "/srv/minecraft/broccoli-bloc/"
          ];
          repository = "sftp:bowman4@100.64.0.6:/mnt/PiBackup/ResticBackups/SmallBackup";
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "10min";
          };
        };
        remotebackup-large = {
          passwordFile = config.sops.secrets.restic-password.path;
          initialize = true;
          extraOptions = [
            "sftp.command='ssh bowman4@100.64.0.6 -i /home/bowman4/.ssh/id_ed25519 -s sftp'"
          ];
          paths = [
            "/mnt/NixServeStorage/Data/Jellyfin"
          ];
          repository = "sftp:bowman4@100.64.0.6:/mnt/PiBackup/ResticBackups/LargeBackup";
          timerConfig = {
            OnCalendar = "weekly";
            Persistent = true;
            RandomizedDelaySec = "10min";
          };
        };
      };
    };

    systemd = {
      timers = {
        "restic-localbackup-small-remove" = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            Unit = "restic-localbackup-small-remove.service";
          };
        };
        "restic-cloudbackup-small-remove" = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "monthly";
            Persistent = true;
            Unit = "restic-cloudbackup-small-remove.service";
          };
        };
        "restic-remotebackup-small-remove" = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            Unit = "restic-remotebackup-small-remove.service";
          };
        };
        "restic-remotebackup-large-remove" = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "weekly";
            Persistent = true;
            Unit = "restic-remotebackup-large-remove.service";
          };
        };
      };
      services = {
        "restic-localbackup-small-remove" = {
          serviceConfig = {
            ExecStart = ''/run/current-system/sw/bin/restic-localbackup-small forget --keep-daily 7 --keep-weekly 26 --prune '';
            Type = "oneshot";
            User = "root";
          };
        };
        "restic-cloudbackup-small-remove" = {
          serviceConfig = {
            ExecStart = ''/run/current-system/sw/bin/restic-cloudbackup-small forget --keep-weekly 53 --prune '';
            Type = "oneshot";
            User = "root";
          };
        };
        "restic-remotebackup-small-remove" = {
          serviceConfig = {
            ExecStart = ''/run/current-system/sw/bin/restic-remotebackup-small forget --keep-daily 7 --keep-weekly 26 --prune '';
            Type = "oneshot";
            User = "root";
          };
        };
        "restic-remotebackup-large-remove" = {
          serviceConfig = {
            ExecStart = ''/run/current-system/sw/bin/restic-remotebackup-large forget --keep-weekly 26 --prune '';
            Type = "oneshot";
            User = "root";
          };
        };
      };
    };
  };
}
