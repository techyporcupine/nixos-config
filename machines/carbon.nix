{
  config,
  lib,
  pkgs,
  ...
}: {
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
    tailscale = true;
    avahi = true;
  };

  services.tailscale = {
    useRoutingFeatures = "client";
  };

  # GRAPHICS CONFIG
  tp.graphics = {
    enable = true;
    kitty = true;
    sway = true;
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
  networking.firewall.allowedTCPPorts = [19132];

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
    tpm2-tss
    amdgpu_top
    ookla-speedtest
    blackmagic-desktop-video
    krita
    tidal-hifi
    davinci-resolve
  ];

  # FIXME: When installing this flake, comment out the following 5 lines until you have rebooted into the new system and decide you want secure boot!
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };

  # Set up TPM Decryption
  boot.initrd.systemd.enable = true;

  boot = {
    # Set resume offset for swapfile and turn off AMD ABM. Also do some AMD setting to try to get rid of screen flash.
    kernelParams = [
      "resume_offset=533760"
      "amdgpu.abmlevel=0"
    ];
    # Specify device to get the resume swapfile from
    resumeDevice = "/dev/disk/by-label/nixos";
  };

  # Enable 6GHz
  hardware.wirelessRegulatoryDatabase = true;
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=US
  '';

  ################################################################################
  ###### DO NOT MODIFY BELOW THIS UNLESS YOU KNOW EXACTLY WHAT YOU'RE DOING ######
  ################################################################################
  boot.initrd.availableKernelModules = ["xhci_pci" "usb_storage" "uas" "sd_mod" "thunderbolt" "nvme"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];

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
