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
    llama-server = {
      enable = true;
    };
    beszel = {
      client = {
        enable = true;
        sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINiQASN4BziJ9E1RwymKo5KKri6PBC4UP76YASLDZfrr";
      };
    };
  };

  # Hardware-parameterized LLM packages
  # Dual GPU: NVIDIA RTX 3080 Ti (sm_86) + AMD Instinct MI50 (gfx906)
  # Uses dynamic backend loading (GGML_BACKEND_DL) for runtime GPU selection
  services.franken-llama = {
    enable = true;
    acceleration = "dual";
    nativeCpu = true;
    llguidance = true;

    # GPU architecture targets
    cudaCapabilities = ["75" "86"]; # GTX 1650 (sm_75 / Turing), RTX 3080 Ti (sm_86 / Ampere)
    rocmTargets = ["gfx906"]; # MI50 (Vega 20)

    # To override the default b9305 version on this specific machine,
    # define llamaCppTag and its Nix SHA256 hash below:
    llamaCppTag = "b9310";
    llamaCppHash = "sha256-XJwh8bPrbhckZkwiS6i3tNGW5Ujeh7hqU3YL6HiS1Ro=";
  };

  # Graphics (NVIDIA)
  tp.graphics.nvidia.enable = true;

  # Custom GPU Optimization Service for both NVIDIA RTX 3080 Ti and AMD Instinct MI50
  systemd.services.gpu-optimization = {
    description = "Optimize GPU power limits and performance settings";
    wantedBy = ["multi-user.target"];

    # Packaged tools made available to the service shell script environment
    path = [
      config.hardware.nvidia.package # Provides nvidia-smi
      pkgs.pciutils # Provides lspci
      (pkgs.callPackage ../nixos/pkgs/upp.nix {}) # Provides sibradzic's upp tool
      pkgs.gawk # Provides awk
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "/home/${config.tp.username}/nixos-config/nixos/graphics/gpu-optimize.sh";
    };
  };

  # GPU Fan Controller for AMD MI50 (reads temp, controls motherboard fan header)
  systemd.services.gpu-fan-control = {
    description = "AMD MI50 GPU Fan Controller";
    after = ["multi-user.target"];
    wantedBy = [ "multi-user.target" ];  # uncomment to auto-start

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.callPackage ../nixos/graphics/gpu-fan-control {}}/bin/gpu-fan-control /home/${config.tp.username}/nixos-config/nixos/graphics/gpu-fan-control/gpu-fan-control.conf";
      Restart = "always";
      RestartSec = "5s";
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      8080
      # frigate web
      8971
      # rtsp/webrtc
      8554
      8555
    ];
    allowedUDPPorts = [
      # webrtc
      8555
    ];
  };

  # Git identity for home-manager
  tp.hm.programs.git.settings.user.name = "techyporcupine";
  tp.hm.programs.git.settings.user.email = "git@cb-tech.me";

  # Machine-specific packages
  environment.systemPackages = with pkgs; [
    llama-cpp
    python3Packages.huggingface-hub
    rocmPackages.rocminfo
    rocmPackages.rocm-smi
    amdgpu_top
    (pkgs.callPackage ../nixos/pkgs/upp.nix {})
    (pkgs.callPackage ../nixos/graphics/amd {})
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
        frigate = let
          customRocblas = pkgs.rocmPackages.rocblas.override {
            gpuTargets = ["gfx906"];
          };
        in {
          image = "ghcr.io/blakeblackshear/frigate:stable-rocm";
          autoStart = true;
          extraOptions = [
            "--privileged"
            "--shm-size=512m"
            "--stop-timeout=30"
            "--cap-add=CAP_PERFMON"
            "--device=/dev/kfd"
            "--device=/dev/dri"
            "--group-add=303" # render group for GPU
            "--group-add=26" # video group for GPU
          ];
          # Map your hardware devices
          devices = [
            "/dev/dri/renderD128:/dev/dri/renderD128"
          ];
          # Map your ports
          ports = [
            "8971:8971"
            "8554:8554"
            "8555:8555/tcp"
            "8555:8555/udp"
          ];
          # Set environment variables
          environment = {
            FRIGATE_RTSP_PASSWORD = "password";
            HSA_OVERRIDE_GFX_VERSION = "9.0.6";
            ROCBLAS_TENSILE_LIBPATH = "${customRocblas}/lib/rocblas/library";
          };
          # Map your volumes
          volumes = [
            "/etc/localtime:/etc/localtime:ro"
            "/home/nitrogen/frigate/config:/config"
            "/mnt/Storage/frigate/media:/media/frigate"
            "${customRocblas}/lib/rocblas/library:${customRocblas}/lib/rocblas/library:ro"
          ];
        };
      };
    };
  };

  nixpkgs.config.cudaSupport = true;

  fileSystems."/mnt/Storage" = {
    device = "/dev/disk/by-label/Storage";
    fsType = "ext4";
    options = [
      "defaults"
      "noatime" # Don't update "last accessed" timestamps
      "nobarrier" # Skip the "wait for platter" signal (huge speed boost)
      "commit=30" # Group writes into 5-minute chunks
      "data=writeback" # Don't journal the data, only the file structure
    ];
  };

  boot.kernel.sysctl = {
    # Keep the 8GB RAM free for system/apps
    "vm.dirty_background_ratio" = 1;
    "vm.dirty_ratio" = 5;
    # Optimize for large sequential writes
    "vm.swappiness" = 10;
  };

  boot.loader.systemd-boot.enable = true;

  # Initrd + boot (enable systemd initrd for early userspace hooks)
  boot.initrd.systemd.enable = true;

  # Enable AMDGPU Overdrive feature mask for overclocking/undervolting support on the AMD Instinct MI50
  boot.kernelParams = ["amdgpu.ppfeaturemask=0xfffd7fff"];

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
  boot.kernelModules = ["kvm-intel" "nct6775"];
  boot.extraModulePackages = [];

  # Default: enable DHCP on interfaces unless overridden per-interface
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp2s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
