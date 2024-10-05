{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.tp.disks;
in {
  options.tp.disks = {
    enable = lib.mkEnableOption "TP's disk config";
  };

  config = lib.mkIf cfg.enable {
    # BOOT CONFIG
    boot = {
      loader.systemd-boot.enable = true;
      loader.efi.canTouchEfiVariables = true;
      plymouth = {
        enable = true; #  Enable plymouth for nice boot and shutdown screens
      };
      kernelPackages = pkgs.linuxPackages_latest; # Get latest kernel
    };
  };
}
