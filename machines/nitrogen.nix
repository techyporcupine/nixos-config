{
  config,
  lib,
  pkgs,
  ...
}: {
  # Machine: nitrogen
  # Purpose: per-machine Nix configuration and local overrides for 'nitrogen'.
  tp.nix.enable = true;
  system.stateVersion = "25.05";
  tp.hm.home.stateVersion = "25.05";
  nixpkgs = {
    config = {
      permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
      #packageOverrides = pkgs: {
      #  vaapiIntel = pkgs.vaapiIntel.override {enableHybridCodec = true;};
      #};
    };
  };

  # User account
  tp.username = "nitrogen";
  tp.fullName = "nitrogen";

  # Boot & disks
  tp.disks = {
    enable = true;
  };

  # System features
  tp.system = {
    enable = true;
  };

  # Networking
  networking.hostName = "nitrogen";
  tp.networking = {
    enable = true;
    avahi = true; # mDNS
  };

  # Server/client services
  tp.server = {
    llama-swap.enable = true;
    beszel = {
      client = {
        enable = true;
        sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINiQASN4BziJ9E1RwymKo5KKri6PBC4UP76YASLDZfrr";
      };
    };
  };

  # Graphics (NVIDIA)
  tp.graphics.nvidia.enable = true;

  networking.firewall = {
    allowedTCPPorts = [
      10300
      8080
      11434
    ];
  };

  # Git identity for home-manager
  tp.hm.programs.git.settings.user.name = "techyporcupine";
  tp.hm.programs.git.settings.user.email = "git@cb-tech.me";

  # Machine-specific packages
  environment.systemPackages = with pkgs; [
    #llama-cpp-cuda-native-llguidance
  ];

  # Local overlays (adds project-specific package overlays)
  nixpkgs.overlays = [
    (import ../nixos/pkgs/ollama-overlay.nix)
  ];

  # Virtualisation & containers (podman backend + OCI container entries)
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
            WEBUI_URL = "https://llm.local.cb-tech.me";
            ENABLE_OAUTH_SIGNUP = "true";
            OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "true";
            ENABLE_LOGIN_FORM = "false";
            OPENAI_API_BASE_URL = "http://127.0.0.1:5349/v1";
            OPENAI_API_KEY = "abc123";
          };
          environmentFiles = [/var/secrets/open-webui];
          extraOptions = [
            "--pull=newer" # Pull if the image on the registry is newer than the one in the local containers storage
            "--network=host"
          ];
        };
        frigate = {
          image = "ghcr.io/blakeblackshear/frigate:stable";
          autoStart = true;
          extraOptions = [
            "--privileged"
            "--shm-size=512m"
            "--stop-timeout=30"
            "--cap-add=CAP_PERFMON"
          ];
          # Map your hardware devices
          devices = [
            "/dev/dri/renderD128:/dev/dri/renderD128"
          ];
          # Map your ports
          ports = [
            "8971:8971"
            "5000:5000"
            "8554:8554"
            "8555:8555/tcp"
            "8555:8555/udp"
          ];
          # Set environment variables
          environment = {
            FRIGATE_RTSP_PASSWORD = "password";
          };
          # Map your volumes
          volumes = [
            "/etc/localtime:/etc/localtime:ro"
            "/home/nitrogen/frigate/config:/config"
            "/home/nitrogen/frigate/storage:/media/frigate"
          ];
        };
      };
    };
  };

  nixpkgs.config.cudaSupport = true;

  boot.loader.systemd-boot.enable = true;

  # Initrd + boot (enable systemd initrd for early userspace hooks)
  boot.initrd.systemd.enable = true;

  # Graphics-related packages (VA-API / VDPAU helpers)
  hardware.graphics = {
    enable = true;
    # extraPackages = with pkgs; [
    #   intel-media-driver # iHD
    #   vaapiIntel # i965 (legacy)
    #   vaapiVdpau
    #   libvdpau-va-gl
    # ];
    # enable32Bit = true;
  };

  # --- System footer: kernel/initrd/network defaults ---
  # Tunable defaults for kernel/initrd modules and networking. Edit only when required for boot/device support.
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "sr_mod" "rtsx_usb_sdmmc"];
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
