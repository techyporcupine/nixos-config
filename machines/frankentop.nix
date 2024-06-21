{ config, lib, pkgs, ... }:

{
  # NIX CONFIGURATION
  tp.nix.enable = true;
  system.stateVersion = "24.11";

  # BOOT AND DISKS CONFIG
  disko.devices.disk.vdb.device = "/dev/disk/by-id/ata-JAJMS300M120G_AB202200000210001291";
  tp.disks = {
    enable = true;
  };

  # SYSTEM CONFIG
  tp.system = {
    enable = true;
  };

  # NETWORKING CONFIG
  networking.hostName = "frankentop";
  tp.networking = {
    enable = true;
    tailscale.client.enable = true;
    avahi.enable = true;
  };

  # GRAPHICS CONFIG
  tp.graphics = {
    enable = true;
    nvidia = {
      enable = true;
      prime.enable = true;
    };
    hwaccel.enable = true;
  };

  # GAMING CONFIG
  tp.gaming = {
    enable = true;
  };

  # USER CONFIG
  tp.user = {
    enable = true;
  };

  # PACKAGES JUST FOR THIS MACHINE
  environment.systemPackages = with pkgs; [
    yt-dlp
    blisp
    nodejs
    nodePackages_latest.pnpm
    hugo
  ];

  ################################################################################
  ###### DO NOT MODIFY BELOW THIS UNLESS YOU KNOW EXACTLY WHAT YOU'RE DOING ######
  ################################################################################
  boot.initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usb_storage" "uas" "sd_mod" "sdhci_pci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" "btintel" ];

  hardware.enableRedistributableFirmware = lib.mkDefault true; 
  
  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp2s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
