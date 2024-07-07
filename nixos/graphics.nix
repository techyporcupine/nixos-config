# TODO: COMMENTS and fix Nvidia xserver driver thingys
{pkgs, config, lib, inputs, ... }: let cfg = config.tp.graphics; in {
  options.tp.graphics = {
    enable = lib.mkEnableOption "TP's graphics stack";
    nvidia.enable = lib.mkEnableOption "enable nVidia driver stuff";
    nvidia.prime.enable = lib.mkEnableOption "enable nVidia prime config";
    hwaccel.enable = lib.mkEnableOption "hardware acceleration";
  };

  config = lib.mkIf cfg.enable {
    # HARDWARE ACCELERATION CONFIGURATION
    hardware = {
      graphics = lib.mkIf cfg.hwaccel.enable {
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
    nixpkgs.config = lib.mkIf cfg.hwaccel.enable {
      packageOverrides = pkgs: {
        vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
      };
    };
    boot = lib.mkIf cfg.hwaccel.enable {
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
      package = let 
        rcu_patch = pkgs.fetchpatch {
          url = "https://github.com/gentoo/gentoo/raw/c64caf53/x11-drivers/nvidia-drivers/files/nvidia-drivers-470.223.02-gpl-pfn_valid.patch";
          hash = "sha256-eZiQQp2S/asE7MfGvfe6dA/kdCvek9SYa/FFGp24dVg=";
        };
      in config.boot.kernelPackages.nvidiaPackages.mkDriver {
        version = "535.154.05";
        sha256_64bit = "sha256-fpUGXKprgt6SYRDxSCemGXLrEsIA6GOinp+0eGbqqJg=";
        sha256_aarch64 = "sha256-G0/GiObf/BZMkzzET8HQjdIcvCSqB1uhsinro2HLK9k=";
        openSha256 = "sha256-wvRdHguGLxS0mR06P5Qi++pDJBCF8pJ8hr4T8O6TJIo=";
        settingsSha256 = "sha256-9wqoDEWY4I7weWW05F4igj1Gj9wjHsREFMztfEmqm10=";
        persistencedSha256 = "sha256-d0Q3Lk80JqkS1B54Mahu2yY/WocOqFFbZVBh+ToGhaE=";

        #version = "550.40.07";
        #sha256_64bit = "sha256-KYk2xye37v7ZW7h+uNJM/u8fNf7KyGTZjiaU03dJpK0=";
        #sha256_aarch64 = "sha256-AV7KgRXYaQGBFl7zuRcfnTGr8rS5n13nGUIe3mJTXb4=";
        #openSha256 = "sha256-mRUTEWVsbjq+psVe+kAT6MjyZuLkG2yRDxCMvDJRL1I=";
        #settingsSha256 = "sha256-c30AQa4g4a1EHmaEu1yc05oqY01y+IusbBuq+P6rMCs=";
        #persistencedSha256 = "sha256-11tLSY8uUIl4X/roNnxf5yS2PQvHvoNjnd2CB67e870=";

        patches = [ rcu_patch ];
      };
      
      prime = lib.mkIf cfg.nvidia.prime.enable {
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
      gnome-connections
      vlc
      helvum
      obs-studio
      gimp
      slack
      pkgsCuda.blender
      gnome.cheese
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

      # needed for hyprland
      gnome.nautilus
      gnome.gnome-disk-utility
      gnome.gnome-tweaks
      udiskie
      baobab
      gnome.adwaita-icon-theme
      catppuccin-papirus-folders
      polkit_gnome
      gnome.gnome-logs
      gnome.gnome-system-monitor
      gnome.gnome-font-viewer
      grim
      slurp
      catppuccin-cursors.mochaGreen
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

    # Enable blueman for bluetooth managment
    services.blueman.enable = true;
    # Enable gnome-keyring
    services.gnome.gnome-keyring.enable = true;
    # X11/Wayland Configuration
    services.xserver = {
      enable = true;
      displayManager.gdm.enable = true;
      videoDrivers = lib.mkIf cfg.nvidia.enable [ "nvidia" "modesetting" ];
    };
    # Enable CUPS to print docs
    services.printing.enable = true;
    # Enable udisks for drive utils
    services.udisks2.enable = true;

    programs.hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    };
    
    # Enable dconf
    programs.dconf.enable = true; 

    # Enable seahorse key and password managment
    programs.seahorse.enable = true;
      
    systemd = {
      # Add config for starting polkit via systemD
      user.services.polkit-gnome-authentication-agent-1 = {
        description = "polkit-gnome-authentication-agent-1";
        wantedBy = [ "graphical-session.target" ];
        wants = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 10;
        };
      };
    };

  };
}