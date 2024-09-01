{ config, lib, pkgs, ... }:

{
  # NIX CONFIGURATION
  tp.nix.enable = true;
  system.stateVersion = "24.11";
  tp.hm.home.stateVersion = "24.11";

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
  networking.hostName = "carbon";
  tp.networking = {
    enable = true;
    tailscale.client = true;
    avahi = true;
  };

  # GRAPHICS CONFIG
  tp.graphics = {
    enable = true;
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
    graphical = true;
  };

  # Git config
  tp.hm.programs.git.userName = "techyporcupine";
  tp.hm.programs.git.userEmail = "git@cb-tech.me";

  # TCP Ports out of firewall
  networking.firewall.allowedTCPPorts = [ 19132 3000 ];

  # PACKAGES JUST FOR THIS MACHINE
  environment.systemPackages = with pkgs; [
    yt-dlp
    blisp
    nodejs
    nodePackages_latest.pnpm
    hugo
    libhdhomerun
    hdhomerun-config-gui
    fw-ectool
    blender-hip
  ];

  # Enable fw-fanctrl
  programs.fw-fanctrl.enable = true;
  programs.fw-fanctrl.config = {
    defaultStrategy = "lazy";
    strategies = {
      "lazy" = {
        fanSpeedUpdateFrequency = 5;
        movingAverageInterval = 25;
        speedCurve = [
          { temp = 45; speed = 0; }
          { temp = 54; speed = 0; }
          { temp = 55; speed = 15; }
          { temp = 65; speed = 25; }
          { temp = 70; speed = 40; }
          { temp = 75; speed = 60; }
          { temp = 85; speed = 100; }
        ];
      };
    };
  };

  # Turn off AMD ABM
  boot.kernelParams = [ "amdgpu.abmlevel=0" ];
  
  # Enable 6GHz
  hardware.wirelessRegulatoryDatabase = true;
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=US
  '';

  ################################################################################
  ###### DO NOT MODIFY BELOW THIS UNLESS YOU KNOW EXACTLY WHAT YOU'RE DOING ######
  ################################################################################
  boot.initrd.availableKernelModules = [ "xhci_pci" "usb_storage" "uas" "sd_mod" "thunderbolt" "nvme" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  hardware.enableRedistributableFirmware = lib.mkDefault true; 
  
  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp2s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
