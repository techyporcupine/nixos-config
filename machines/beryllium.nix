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
  nixpkgs = {
    config = {
      permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
      packageOverrides = pkgs: {
        vaapiIntel = pkgs.vaapiIntel.override {enableHybridCodec = true;};
      };
    };
  };

  # USER CONFIG
  tp.username = "beryllium";
  tp.fullName = "beryllium";

  # BOOT AND DISKS CONFIG
  tp.disks = {
    enable = true;
  };

  # SYSTEM CONFIG
  tp.system = {
    enable = true;
  };

  # NETWORKING CONFIG
  networking.hostName = "beryllium";
  tp.networking = {
    enable = true;
    avahi = true;
  };
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

  time = {
    timeZone = lib.mkForce "America/New_York";
  };

  tp.server = {
    minecraft.enable = true;
    minecraft.broccoli-bloc = true;
    traefik.enable = true;
    vaultwarden.enable = true;
    uptime-kuma.enable = true;
    virtualisation.enable = true;
    virtualisation.containers.enable = true;
    home-assistant.enable = true;
    plausible.enable = false;
    unifi.enable = true;
    immich.enable = true;
    backups.client.enable = true;
    jellyfin.enable = true;
    beszel.enable = true;
    grafana = {
      enable = true;
    };
    librenms.enable = true;
    matrix.enable = true;
    akvorado.enable = false;
    authentik.enable = true;
  };

  services.caddy = {
    enable = true;
    extraConfig = ''
      :18085 {
          root * /var/www/static
          file_server
      }
    '';
  };

  systemd.services.beszel = {
    enable = true;
    path = [pkgs.beszel];
    serviceConfig = {
      ExecStart = "${pkgs.beszel}/bin/beszel-agent";
    };
    environment = {
      LISTEN = "45876";
      KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINiQASN4BziJ9E1RwymKo5KKri6PBC4UP76YASLDZfrr";
      #EXTRA_FILESYSTEMS = "/mnt/1TB_Backup";
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

  # Git config
  tp.hm.programs.git.userName = "techyporcupine";
  tp.hm.programs.git.userEmail = "git@cb-tech.me";

  # PACKAGES JUST FOR THIS MACHINE
  environment.systemPackages = with pkgs; [
    # llama-cpp-vulkan-native
  ];

  boot.loader.systemd-boot.enable = true;

  # Set up systemd initrd
  boot.initrd.systemd.enable = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # LIBVA_DRIVER_NAME=iHD
      vaapiIntel # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
      vaapiVdpau
      libvdpau-va-gl
    ];
    enable32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
    # of just the bare essentials.
    powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    open = true;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Disable SWAP
  swapDevices = lib.mkForce [];

  ################################################################################
  ###### DO NOT MODIFY BELOW THIS UNLESS YOU KNOW EXACTLY WHAT YOU'RE DOING ######
  ################################################################################
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
