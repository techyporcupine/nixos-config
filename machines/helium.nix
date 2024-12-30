{
  config,
  lib,
  pkgs,
  ...
}: {
  # NIX CONFIGURATION
  tp.nix.enable = true;
  system.stateVersion = "24.05";
  tp.hm.home.stateVersion = "24.05";

  # USER CONFIG
  tp.username = "helium";
  tp.fullName = "helium";

  # BOOT AND DISKS CONFIG
  tp.disks = {
    enable = true;
  };

  # SYSTEM CONFIG
  tp.system = {
    enable = true;
  };

  # NETWORKING CONFIG
  networking.hostName = "helium";
  tp.networking = {
    enable = true;
    avahi = true;
  };

  # HOSTED SERVICES CONFIG
  tp.server.backups.server.enable = true;

  services.tailscale = {
    # Enable tailscale mesh network
    enable = true;
    useRoutingFeatures = "both";
    extraUpFlags = [
      "--ssh"
      "--advertise-exit-node"
    ];
  };

  # Git config
  tp.hm.programs.git.userName = "techyporcupine";
  tp.hm.programs.git.userEmail = "git@cb-tech.me";

  # PACKAGES JUST FOR THIS MACHINE
  environment.systemPackages = with pkgs; [
  ];

  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub.enable = lib.mkForce false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = lib.mkForce true;

  # Mount 1TB Hard drive
  fileSystems."/mnt/1TB_Backup" = {
    device = "/dev/disk/by-label/1TB_Backup";
    fsType = "ext4";
  };

  ################################################################################
  ###### DO NOT MODIFY BELOW THIS UNLESS YOU KNOW EXACTLY WHAT YOU'RE DOING ######
  ################################################################################
  boot.initrd.availableKernelModules = ["xhci_pci" "uas"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
    fsType = "ext4";
  };

  swapDevices = [];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.end0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlan0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
