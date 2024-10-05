{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.backups;
in {
  options.tp.backups = {
    enable = lib.mkEnableOption "Enable Restic backups";
  };

  config = lib.mkIf cfg.enable {
    services.restic = {
      backups = {
        "remotebackup-small" = {
          #passwordFile = ;
          initialize = true;
          extraOptions = [
            "sftp.command='ssh bowman4@100.64.0.6 -i /home/${config.tp.username}/.ssh/id_ed25519 -s sftp'"
          ];
          paths = [
            "/srv/minecraft/"
          ];
          repository = "sftp:bowman4@100.64.0.6:/mnt/PiBackup/ResticBackups/MinecraftBackup";
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "10min";
          };
        };
      };
    };
    systemd = {
      timers = {
        "restic-remotebackup-small-remove" = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            Unit = "restic-remotebackup-small-remove.service";
          };
        };
      };
      services = {
        "restic-remotebackup-small-remove" = {
          serviceConfig = {
            ExecStart = "/run/current-system/sw/bin/restic-remotebackup-small forget --keep-daily 7 --keep-weekly 26 --prune";
            Type = "oneshot";
            User = "root";
          };
        };
      };
    };
  };
}
