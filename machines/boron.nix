{
  config,
  lib,
  pkgs,
  ...
}: {
  # NIX CONFIGURATION
  tp.nix.enable = true;
  system.stateVersion = "25.05";
  tp.hm.home.stateVersion = "25.05";
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
  tp.username = "boron";
  tp.fullName = "boron";

  # BOOT AND DISKS CONFIG
  tp.disks = {
    enable = true;
  };

  # SYSTEM CONFIG
  tp.system = {
    enable = true;
  };

  # NETWORKING CONFIG
  networking.hostName = "boron";
  tp.networking = {
    enable = true;
    avahi = true;
  };

  tp.server = {
    llama-swap.enable = true;
    beszel = {
      client = {
        enable = true;
        sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINiQASN4BziJ9E1RwymKo5KKri6PBC4UP76YASLDZfrr";
      };
    };
  };

  tp.graphics.nvidia.enable = true;
  tp.graphics.nvidia.prime = true;

  networking.firewall = {
    allowedTCPPorts = [
      10200
      10300
      8080
      11434
    ];
  };

  # Git config
  tp.hm.programs.git.userName = "techyporcupine";
  tp.hm.programs.git.userEmail = "git@cb-tech.me";

  # PACKAGES JUST FOR THIS MACHINE
  environment.systemPackages = with pkgs; [
    llama-cpp-cuda-native
    handbrake
  ];

  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    openFirewall = true;
    acceleration = "cuda";
  };

  virtualisation = {
    podman = {
      enable = true;

      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;

      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };
    oci-containers = {
      backend = "podman";
      containers = {
        open-webui = {
          image = "ghcr.io/open-webui/open-webui:main";
          volumes = ["/home/${config.tp.username}/open-webui:/app/backend/data"];
          autoStart = true;
          environment = {
            OLLAMA_BASE_URL = "http://10.0.0.8:11434";
            WEBUI_AUTH = "False";
          };
          extraOptions = [
            "--pull=newer" # Pull if the image on the registry is newer than the one in the local containers storage
            "--network=host"
          ];
        };
      };
    };
  };

  services.wyoming = {
    piper.servers.boronPiper = {
      enable = true;
      piper = pkgs.stable.piper-tts;
      useCUDA = false; # Breaks as of 9/23/25
      uri = "tcp://0.0.0.0:10200";
      voice = "en_GB-cori-high";
    };
    faster-whisper.servers.boronWhisper = {
      enable = true;
      device = "cpu";
      uri = "tcp://0.0.0.0:10300";
      model = "Systran/faster-distil-whisper-medium.en";
      language = "en";
    };
  };

  nixpkgs.config.cudaSupport = true;

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
