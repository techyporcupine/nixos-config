# TODO: COMMENTS and fix Nvidia xserver driver thingys
{pkgs, config, lib, inputs, ... }: let cfg = config.tp.graphics; in {
  options.tp.graphics = {
    enable = lib.mkEnableOption "TP's graphics stack";
    nvidia.enable = lib.mkEnableOption "enable nVidia driver stuff";
    nvidia.prime = lib.mkEnableOption "enable nVidia prime config";
    hwaccel = lib.mkEnableOption "hardware acceleration";
  };

  config = lib.mkIf cfg.enable {
    # HARDWARE ACCELERATION CONFIGURATION
    hardware = {
      graphics = lib.mkIf cfg.hwaccel {
        enable = true;
        enable32Bit = true;
        # Packages for hardware acceleration
        extraPackages = with pkgs; [
          intel-media-driver # LIBVA_DRIVER_NAME=iHD
          vaapiIntel         # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
          vaapiVdpau
          libvdpau-va-gl
        ];
      };
    };
    nixpkgs.config = lib.mkIf cfg.hwaccel {
      packageOverrides = pkgs: {
        vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
      };
    };
    boot = lib.mkIf cfg.hwaccel {
      extraModulePackages = with config.boot.kernelPackages; [
        v4l2loopback
      ];
    };

    # nVidia Settings
    hardware.nvidia = lib.mkIf cfg.nvidia.enable {
      # Modesetting is needed most of the time
      modesetting.enable = true;

      # Enable power management (do not disable this unless you have a reason to).
      # Likely to cause problems on laptops and with screen tearing if disabled.
      powerManagement.enable = false;

      # Whether to use nouveau or not
      open = false;

      # Enable the Nvidia settings menu, accessible via `nvidia-settings`.
      nvidiaSettings = true;

      # Patches to use version 535 instead of 550 as 550 was causing kernel panics.
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      
      prime = lib.mkIf cfg.nvidia.prime {
        sync.enable = true;
        # Make sure to use the correct Bus ID values for your system!
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:3:0:0";
      };
    };

    tp.rtl-sdr.enable = true;

    # Graphical applications
    environment.systemPackages = with pkgs; [
      firefox
      spotify
      xorg.xeyes
      vlc
      helvum
      obs-studio
      gimp
      slack
      pkgsCuda.blender
      (vscode-with-extensions.override {
        vscode = vscodium;
        vscodeExtensions = with vscode-extensions; [
          bbenoist.nix
          ms-python.python
          ms-vscode-remote.remote-ssh
          catppuccin.catppuccin-vsc
          catppuccin.catppuccin-vsc-icons
        ];
      })
      zed-editor
      chromium
      calibre
      super-slicer-beta
      libreoffice-fresh
      audacity
      pavucontrol
      scrcpy
      yubikey-manager-qt
      yubikey-personalization-gui
      webcord
    ];

    # Globally enable Wayland in electron apps
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    # FONTS CONFIG
    fonts.packages = with pkgs; [
      rPackages.fontawesome
      iosevka
      inconsolata
      roboto-mono
      fira-code-nerdfont
    ];

    # X11/Wayland Configuration
    services.xserver = {
      enable = true;
      videoDrivers = lib.mkIf cfg.nvidia.enable [ "nvidia" "modesetting" ];
    };
    
    # Enable CUPS to print docs
    services.printing.enable = true;

    # TODO: Move to GTK
    # Enable dconf
    programs.dconf.enable = true; 
  };
}