{ config, lib, pkgs, ... }:

{
  # NIX CONFIGURATION
  tp.nix.enable = true;
  system.stateVersion = "24.05";
  tp.hm.home.stateVersion = "24.05";

  # USER CONFIG
  tp.username = "lithium";
  tp.fullName = "lithium";

  # BOOT AND DISKS CONFIG
  tp.disks = {
    enable = true;
  };

  # SYSTEM CONFIG
  tp.system = {
    enable = true;
  };

  # NETWORKING CONFIG
  networking.hostName = "lithium";
  tp.networking = {
    enable = true;
    tailscale.client = false;
    avahi = false;
  };

  # GRAPHICS CONFIG
  tp.graphics = {
    enable = false;
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
    graphical = false;
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
    
  ];
  
  # SOPS CONFIG
  #sops = {
  #  # FIXME: If you are using this repo, make sure that you change this to the actual path to this repo
  #  defaultSopsFile = "/home/${config.tp.username}/nixos-config/secrets/secrets.yaml";
  #  defaultSopsFormat = "yaml";
  #  validateSopsFiles = false;

  #  age.keyFile = "/home/${config.tp.username}/.config/sops/age/keys.txt";

  #  secrets."hello" = {};
  #};

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
