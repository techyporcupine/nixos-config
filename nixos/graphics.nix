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
      opengl = lib.mkIf cfg.hwaccel.enable {
        enable = true;
        driSupport = true;
        driSupport32Bit = true;
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

      # Optionally, you may need to select the appropriate driver version for your specific GPU.
      package = config.boot.kernelPackages.nvidiaPackages.stable;

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
      blender
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