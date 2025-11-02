{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  # Machine: lithium
  # Purpose: per-machine Nix configuration and local overrides for 'lithium'.
  tp.nix.enable = true;
  system.stateVersion = "25.11";
  tp.hm.home.stateVersion = "25.11";

  # User account
  tp.username = "lithium";
  tp.fullName = "lithium";

  # Boot & disks
  tp.disks = {
    enable = true;
  };

  # System features
  tp.system = {
    enable = true;
  };

  # Networking
  networking.hostName = "lithium";
  tp.networking = {
    enable = true;
    avahi = true; # mDNS
  };

  # Hosted services / clients
  # Per-host services (clients and hosted apps)
  tp.server = {
    beszel = {
      client = {
        enable = true;
        sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINiQASN4BziJ9E1RwymKo5KKri6PBC4UP76YASLDZfrr";
      };
    };
    zipline.enable = true;
  };

  # Git identity for home-manager
  tp.hm.programs.git.userName = "techyporcupine";
  tp.hm.programs.git.userEmail = "git@cb-tech.me";

  # Machine-specific packages
  environment.systemPackages = with pkgs; [
  ];

  #hardware.enableAllHardware = true; # uncomment to enable all detected hardware

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
