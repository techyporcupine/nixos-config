{
  config,
  lib,
  pkgs,
  ...
}: {
  # Machine: boron
  # Purpose: per-machine Nix configuration and local overrides for 'boron'.
  # Sections: Nix config, user, disks, system, networking, services, hardware, footer
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

  # User account
  tp.username = "boron";
  tp.fullName = "boron";

  # Boot & disks
  tp.disks = {
    enable = true;
  };

  # System features
  tp.system = {
    enable = true;
  };

  # Networking
  networking.hostName = "boron";
  tp.networking = {
    enable = true;
    avahi = true; # mDNS
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

  # Graphics (NVIDIA + PRIME for hybrid setups)
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

  # Git identity for home-manager
  tp.hm.programs.git.userName = "techyporcupine";
  tp.hm.programs.git.userEmail = "git@cb-tech.me";

  # Machine-specific packages
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

  # Initrd + bootloader
  boot.initrd.systemd.enable = true;

  # Graphics-related packages (VA-API / VDPAU helpers)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # iHD
      vaapiIntel # i965 (legacy, compatible with some browsers)
      vaapiVdpau
      libvdpau-va-gl
    ];
    enable32Bit = true;
  };

  # --- System footer: kernel/initrd/network defaults ---
  # These options set kernel/initrd modules, default networking behavior, and host platform.
  # Edit only if you understand implications for boot or device support.
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
