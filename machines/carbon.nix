{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  # Machine: carbon
  # Purpose: per-machine Nix configuration and local overrides for 'carbon'.
  # Sections: Nix config, user, disks, system, networking, services, graphics, packages, hardware, footer
  # Notes: 'tp.*' is the project's namespace used across machines for per-host settings.
  tp.nix.enable = true;
  system.stateVersion = "24.11";
  tp.hm.home.stateVersion = "24.11";

  # User account
  tp.username = "techyporcupine";
  tp.fullName = "Caleb";

  # Boot & disks
  tp.disks = {
    enable = true;
  };

  # System features
  tp.system = {
    enable = true;
  };

  # Networking
  networking.hostName = "carbon";
  tp.networking = {
    enable = true;
    avahi = true; # mDNS
  };

  services.tailscale = {
    # Enable tailscale mesh network
    enable = true;
    useRoutingFeatures = "client";
  };

  tp.server.virtualisation.enable = true;

  # Graphics
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

  # Gaming
  tp.gaming = {
    enable = true;
    graphical = true;
  };

  # Git identity for home-manager
  tp.hm.programs.git.settings.user.name = "techyporcupine";
  tp.hm.programs.git.settings.user.email = "git@cb-tech.me";

  # Per-host firewall exceptions (default: none)
  networking.firewall.allowedTCPPorts = [];

  # Machine-specific packages
  environment.systemPackages = with pkgs; [
    yt-dlp
    blisp
    nodejs
    nodePackages_latest.pnpm
    hugo
    libhdhomerun
    hdhomerun-config-gui
    fw-ectool
    pkgsRocm.blender
    tpm2-tss
    amdgpu_top
    krita
    distrobox
    kdePackages.kdenlive
    eog
    qbittorrent
    handbrake
    #calibre
    darktable
    inkscape
    # inputs.companion-satellite.packages.${pkgs.system}.default
    packet
    remmina
    master.esphome
    signal-desktop
    thunderbird
    master.opencode
    unetbootin

    # Copter applications
    qgroundcontrol
    mission-planner
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
      #distroav
    ];
  };

  hardware.amdgpu.opencl.enable = true;
  nixpkgs.config.rocmSupport = true;

  nixpkgs.config.permittedInsecurePackages = [
    "libsoup-2.74.3"
  ];

  # Enable PCSCD for Yubikey
  services.pcscd.enable = true;

  hardware.opentabletdriver.enable = true;

  # Printer Drivers
  services.printing.drivers = [
    pkgs.tp.cups-kyodialog
    pkgs.cups-brother-hll2350dw
  ];

  # Enable power-profiles-daemon for power profile management
  services.power-profiles-daemon.enable = true;

  # Enable Thunderbolt (USB4)
  services.hardware.bolt.enable = true;

  # Force use of Zen kernel
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_zen;

  boot.binfmt.emulatedSystems = ["aarch64-linux"];

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

  services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";

  # Set to hibernate after some time
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=2days
  '';

  # --- System footer: kernel/initrd/network defaults ---
  # These options set kernel/initrd modules, default networking behavior, and host platform.
  # Edit only if you understand implications for boot or device support.
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
