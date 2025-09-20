{
  config,
  lib,
  pkgs,
  inputs,
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
    avahi = true;
  };

  #services.tailscale = {
  #  # Enable tailscale mesh network
  #  enable = true;
  #  useRoutingFeatures = "client";
  #};

  services.cloudflare-warp.enable = true;

  tp.server.virtualisation.enable = true;

  # GRAPHICS CONFIG
  tp.graphics = {
    enable = true;
    kitty = true;
    sway = true;
    mako = true;
    gtk = true;
    rofi = true;
    waybar = true;
    mangohud = true;
    # test if stuff breaks
    qt = false;
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
  networking.firewall.allowedTCPPorts = [19132 10300 9300];

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
    #blender
    tpm2-tss
    amdgpu_top
    krita
    distrobox
    kdePackages.kdenlive
    eog
    qbittorrent
    handbrake
    #inputs.quickemu.packages.${system}.quickemu
    calibre
    darktable
    inkscape
		llama-cpp-vulkan-native
    master.davinci-resolve
    # inputs.companion-satellite.packages.${pkgs.system}.default
    packet
    remmina

    # Copter applications
    qgroundcontrol
    mission-planner
    pio.esphome
    signal-desktop
    thunderbird
  ];

  programs.kdeconnect.enable = true;

  programs.virt-manager.enable = true;
  virtualisation.libvirtd.enable = true;

  programs.ydotool.enable = true;

  users.users.${config.tp.username} = {
    extraGroups = ["ydotool"];
  };

  virtualisation.spiceUSBRedirection.enable = true;

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-ndi
    ];
  };

  hardware.amdgpu.opencl.enable = true;
  nixpkgs.config.rocmSupport = true;

  nixpkgs.config.permittedInsecurePackages = [
    "libsoup-2.74.3"
  ];

  services.ollama = {
    enable = false;
    acceleration = "rocm";
    environmentVariables = {
      # HCC_AMDGPU_TARGET = "gfx1100"; # used to be necessary, but doesn't seem to anymore
      # PYTORCH_ROCM_ARCH = "gfx1100";
      # HSA_ENABLE_SDMA = "0";
      HSA_OVERRIDE_GFX_VERSION = "11.0.3";
      HCC_AMDGPU_TARGET = "gfx1103";
    };
    # rocmOverrideGfx = "11.0.0";
  };

  # Enable PCSCD for Yubikey
  services.pcscd.enable = true;

  hardware.opentabletdriver.enable = true;

  # Kyocera Printer Drivers
  services.printing.drivers = [
    pkgs.stable.cups-kyodialog
    pkgs.cups-brother-hll2350dw
  ];

  # Enable Thunderbolt (USB4)
  services.hardware.bolt.enable = true;

  # Force use of Zen kernel
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_zen;

  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  services.flatpak.enable = true;

  # FIXME: When installing this flake, comment out the following 5 lines until you have rebooted into the new system and decide you want secure boot!
  # boot.loader.systemd-boot.enable = lib.mkForce false;
  # boot.lanzaboote = {
  #   enable = true;
  #   pkiBundle = "/etc/secureboot";
  # };

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

  services.logind = {
    # Set to suspend then hibernate
    lidSwitch = "suspend-then-hibernate";
  };
  # Set to hibernate after some time
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=2days
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
