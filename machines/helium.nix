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
    extraSetFlags = [
      "--advertise-exit-node"
    ];
  };

  # Git config
  tp.hm.programs.git.userName = "techyporcupine";
  tp.hm.programs.git.userEmail = "git@cb-tech.me";

  # PACKAGES JUST FOR THIS MACHINE
  environment.systemPackages = with pkgs; [
  ];

  systemd.services.beszel = {
    enable = true;
    path = [pkgs.beszel];
    serviceConfig = {
      ExecStart = "${pkgs.beszel}/bin/beszel-agent";
      Environment = {
        LISTEN = "45876";
        KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINgCsRuI6F5c9rUILfkDB4xNraMl34fz3capxdrlN7RZ";
      };
    };
    unitConfig = {
      Type = "simple";
    };
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
  };
  networking.firewall = {
    allowedTCPPorts = [
      45876
    ];
  };

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

  ################################################################################
  ###### DO NOT MODIFY BELOW THIS UNLESS YOU KNOW EXACTLY WHAT YOU'RE DOING ######
  ################################################################################
  boot.initrd.availableKernelModules = ["ahci" "xhci_pci" "usbhid" "usb_storage" "sd_mod" "sdhci_pci"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp2s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
