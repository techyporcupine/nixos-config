{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  # Machine: beryllium
  # Purpose: per-machine Nix configuration and local overrides for 'beryllium'.
  tp.nix.enable = true;
  system.stateVersion = "24.11";
  tp.hm.home.stateVersion = "24.11";
  nixpkgs = {
    config = {
      permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
      packageOverrides = pkgs: {
        intel-vaapi-driver = pkgs.intel-vaapi-driver.override {enableHybridCodec = true;};
      };
    };
  };

  # User account
  tp.username = "beryllium";
  tp.fullName = "beryllium";

  # Boot & disks
  tp.disks = {
    enable = true;
  };

  # System features
  tp.system = {
    enable = true;
  };

  # Networking
  networking.hostName = "beryllium";
  tp.networking = {
    enable = true;
    avahi = true; # mDNS
  };
  # Additional networking (VLAN trunk for this host)
  networking = {
    vlans = {
      vlan124 = {
        id = 124;
        interface = "ens18";
      };
    };
    interfaces = {
      vlan124.useDHCP = true; # gets DHCP from existing over trunk
    };
  };

  # Timezone
  # Timezone forced to local region for scheduled tasks and logs
  time = {
    timeZone = lib.mkForce "America/New_York";
  };

  # Services hosted or enabled on this machine (many services live here)
  tp.server = {
    minecraft.enable = true;
    minecraft.broccoli-bloc = true;
    traefik.enable = true;
    vaultwarden.enable = true;
    uptime-kuma.enable = true;
    virtualisation.enable = true;
    virtualisation.containers.enable = true;
    home-assistant.enable = true;
    unifi.enable = true;
    immich.enable = true;
    backups.client.enable = true;
    jellyfin.enable = true;
    beszel = {
      server.enable = true;
      client = {
        enable = true;
        sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINiQASN4BziJ9E1RwymKo5KKri6PBC4UP76YASLDZfrr";
      };
    };
    grafana = {
      enable = true;
    };
    librenms.enable = true;
    matrix.enable = true;
    authentik.enable = true;
    n8n.enable = true;
  };

  # Local Caddy instance for static site on port 18085
  services.caddy = {
    enable = true;
    extraConfig = ''
      :18085 {
          root * /var/www/static
          file_server
      }
    '';
  };

  # Git identity for home-manager
  tp.hm.programs.git.settings.user.name = "techyporcupine";
  tp.hm.programs.git.settings.user.email = "git@cb-tech.me";

  # Machine-specific packages
  environment.systemPackages = with pkgs; [
    # llama-cpp-vulkan-native
  ];

  # Bootloader + initrd
  boot.loader.systemd-boot.enable = true;

  # Initrd + bootloader
  boot.initrd.systemd.enable = true;

  # Graphics-related packages (VA-API / VDPAU helpers)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # iHD
      intel-vaapi-driver # i965 (legacy)
      libva-vdpau-driver
      libvdpau-va-gl
    ];
    enable32Bit = true;
  };

  # Disable swap (explicit override)
  swapDevices = lib.mkForce [];

  # --- System footer: kernel/initrd/network defaults ---
  # Tunable defaults for kernel/initrd modules and networking. Change only when needed.
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "sr_mod" "rtsx_usb_sdmmc"];
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
