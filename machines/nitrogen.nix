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
  tp.username = "nitrogen";
  tp.fullName = "nitrogen";

  # BOOT AND DISKS CONFIG
  tp.disks = {
    enable = true;
  };

  # SYSTEM CONFIG
  tp.system = {
    enable = true;
  };

  # NETWORKING CONFIG
  networking.hostName = "nitrogen";
  tp.networking = {
    enable = true;
    avahi = true;
  };

  tp.server = {
		llama-swap.enable = true;
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
  ];

  nixpkgs.overlays = [
    (import ../nixos/pkgs/ollama-overlay.nix)
  ];

  services.ollama = {
    enable = false;
    host = "0.0.0.0";
    openFirewall = true;
    acceleration = "cuda";
    environmentVariables = {
      OLLAMA_FLASH_ATTENTION = "0";
      GGML_CUDA_FORCE_MMQ = "on";
    };
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
            OLLAMA_BASE_URL = "http://10.0.0.10:11434";
            WEBUI_AUTH = "False";
						OPENAI_API_BASE_URL = "http://127.0.0.1:5349/v1";
						OPENAI_API_KEY=abc123;
          };
          extraOptions = [
            "--pull=newer" # Pull if the image on the registry is newer than the one in the local containers storage
            "--network=host"
          ];
        };
      };
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
