# Boot and disk-related configuration module
# Configures systemd-boot, EFI, Plymouth boot screen, and kernel
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
      # Use systemd-boot as the bootloader (simpler than GRUB for EFI systems)
      loader.systemd-boot.enable = true;
      # Allow modification of EFI variables (needed for boot entry management)
      loader.efi.canTouchEfiVariables = true;
      plymouth = {
        # Enable Plymouth for graphical boot splash screen (hides kernel messages)
        enable = true;
      };
      # Use latest stable kernel instead of LTS (gets newest hardware support)
      kernelPackages = pkgs.linuxPackages_latest;
    };
  };
}
