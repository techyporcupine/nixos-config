{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  # Machine: helium
  # Purpose: per-machine Nix configuration and local overrides for 'helium'.
  tp.nix.enable = true;
  system.stateVersion = "24.11";
  tp.hm.home.stateVersion = "24.11";

  # User account
  tp.username = "helium";
  tp.fullName = "helium";

  # Boot & disks
  tp.disks = {
    enable = true;
  };

  # System features
  tp.system = {
    enable = true;
  };

  # Networking
  networking.hostName = "helium";
  tp.networking = {
    enable = true;
    avahi = true; # mDNS
  };

  # Hosted services / clients
  tp.server.backups.server.enable = true;
  tp.server.beszel = {
    client = {
      enable = true;
      sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINiQASN4BziJ9E1RwymKo5KKri6PBC4UP76YASLDZfrr";
      extraFilesystems = "/mnt/1TB_Backup"; # additional mount for backups
    };
  };

  # Git identity for home-manager
  tp.hm.programs.git.userName = "techyporcupine";
  tp.hm.programs.git.userEmail = "git@cb-tech.me";

  # Machine-specific packages
  environment.systemPackages = with pkgs; [
  ];

  system.autoUpgrade = {
    enable = true;
    flake = inputs.self.outPath;
    flags = [
      "--update-input"
      "nixpkgs-stable"
    ];
    dates = "monthly";
    rebootWindow = {
      lower = "03:00";
      upper = "05:00";
    };
    allowReboot = true;
  };

  # Mount 1TB Hard drive
  fileSystems."/mnt/1TB_Backup" = {
    device = "/dev/disk/by-label/1TB_Backup";
    fsType = "ext4";
    options = ["sync"];
  };

  boot.plymouth.enable = lib.mkForce false;

  #hardware.enableAllHardware = true;

  # --- System footer: kernel/initrd/network defaults ---
  # Tunable defaults for kernel/initrd modules and networking. Edit only when required for boot/device support.
  boot.initrd.availableKernelModules = ["ahci" "xhci_pci" "usbhid" "usb_storage" "sd_mod" "sdhci_pci"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  # Default: enable DHCP on interfaces unless overridden per-interface
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp2s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
