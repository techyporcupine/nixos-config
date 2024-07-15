{ config, lib, pkgs, ... }:

{
  # NIX CONFIGURATION
  tp.nix.enable = true;
  system.stateVersion = "24.11";
  tp.hm.home.stateVersion = "23.05";

  # USER CONFIG
  tp.username = "techyporcupine";
  tp.fullName = "Caleb";

  # BOOT AND DISKS CONFIG
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
    tailscale.client = true;
    avahi = true;
  };

  # GRAPHICS CONFIG
  tp.graphics = {
    enable = true;
    nvidia = {
      enable = true;
      prime = true;
    };
    hwaccel = true;
    kitty = true;
    hyprland = true;
    swaync = true;
    gtk = true;
    rofi = true;
    waybar = true;
    mangohud = true;
    qt = true;
  };

  # GAMING CONFIG
  tp.gaming = {
    enable = true;
    minecraft-server = {
      enable = true;
      broccoli-bloc = true;
    };
  };

  # Git config
  tp.hm.programs.git.userName = "techyporcupine";
  tp.hm.programs.git.userEmail = "git@cb-tech.me";

  # PACKAGES JUST FOR THIS MACHINE
  environment.systemPackages = with pkgs; [
    yt-dlp
    blisp
    nodejs
    nodePackages_latest.pnpm
    hugo
    libhdhomerun
    hdhomerun-config-gui
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
