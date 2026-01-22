{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.graphics;
in {
  options.tp.graphics = {
    sway = lib.mkEnableOption "Enable Sway and all things required for it to work";
  };

  config = lib.mkIf cfg.sway {
    # Enable policykit for reasons
    security.polkit.enable = true;

    # Enable udisks for drive utils
    services.udisks2.enable = true;

    # GDM for logging in
    services = {
      displayManager.gdm.enable = true;
    };

    # Enable blueman for bluetooth managment
    services.blueman.enable = true;

    # Enable gnome-keyring
    services.gnome.gnome-keyring.enable = true;

    # Enable Seahorse for key and password management
    programs.seahorse.enable = true;

    # Desktop utilities and Wayland tools
    environment.systemPackages = with pkgs; [
      nautilus # File manager
      nautilus-python # Python extensions for Nautilus
      python3Packages.dbus-python # DBus Python bindings
      gnome-disk-utility # Disk management tool
      gnome-tweaks # GNOME settings tweaker
      udiskie # Automount removable drives
      baobab # Disk usage analyzer
      polkit_gnome # PolicyKit authentication agent
      gnome-logs # System log viewer
      cheese # Webcam application
      gnome-connections # Remote desktop client
      inputs.hyprpaper.packages.${system}.hyprpaper # Wallpaper utility
      inputs.hypridle.packages.${system}.hypridle # Idle daemon
      hyprlock # Screen locker
      hyprpicker # Color picker
      cliphist # Clipboard manager
      wl-clipboard # Wayland clipboard utilities
      stable.nwg-displays # Display configuration tool
      (flameshot.override {enableWlrSupport = true;}) # Screenshot tool
    ];

    security.pam.services.hyprlock = {
      rules.auth.unix.order = config.security.pam.services.hyprlock.rules.auth.fprintd.order - 10;
    };

    # Use Vulkan renderer for Wayland
    environment.sessionVariables.WLR_RENDERER = "vulkan";

    # Enable Sway window manager
    programs.sway = {
      enable = true;
    };

    # Configure XDG desktop portals for Wayland
    xdg.portal = {
      enable = true;
      # Enable wlroots portal
      wlr.enable = true;
      # Add GTK portal
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
      # Prefer wlr, then gtk
      config.common.default = ["wlr" "gtk"];
    };

    tp.hm = {
      # Files to copy to a location in the home directory
      xdg.configFile."hyprpaper" = {
        enable = true;
        source = ../hypr/hyprpaper.conf;
        target = "hypr/hyprpaper.conf";
      };
      xdg.configFile."hypridle" = {
        enable = true;
        source = ../hypr/hypridle.conf;
        target = "hypr/hypridle.conf";
      };
      xdg.configFile."hyprlock" = {
        enable = true;
        source = ../hypr/hyprlock.conf;
        target = "hypr/hyprlock.conf";
      };
      xdg.configFile."wallpapers" = {
        enable = true;
        source = ../hypr/wallpapers;
        target = "hypr/wallpapers";
      };
      xdg.configFile."icc" = {
        enable = true;
        source = ./assets/BOE_FW13AMD.icm;
        target = "../.color/icc/BOE_FW13AMD.icm";
      };

      wayland.windowManager.sway = {
        enable = true;
        checkConfig = false;
        config = rec {
          modifier = "Mod4";
          # Use kitty as default terminal
          terminal = "kitty";
          startup = [
            # Launch some applications on start
            {command = "firefox";}
            {command = "hyprpaper";}
            {command = "hypridle";}
            {command = "udiskie";}
            {command = "wl-paste --watch cliphist store";}
            {command = "dbus-update-activation-environment --all";}
          ];
          # Set default workspace to be workspace 1
          defaultWorkspace = "workspace number 1";
          output = {
            eDP-1 = {
              color_profile = "icc ~/.color/icc/BOE_FW13AMD.icm";
            };
          };
          # Set command used to launch dmenu
          menu = "zsh -c 'rofi -show drun'";
          # Disable swaybar
          bars = [];
          # Window related settings
          window = {
            border = 2;
          };
          # Set the colors for focused windows
          colors.focused = {
            background = "#89dceb";
            border = "#89dceb";
            childBorder = "#89dceb";
            indicator = "#89dceb";
            text = "#000000";
          };
          # Set window gaps
          gaps = {
            inner = 6;
          };
          # Input device configuration: change touchpad interface for these to apply on other devices
          input = {
            "2362:628:PIXA3854:00_093A:0274_Touchpad" = {
              dwt = "disabled";
              tap = "enabled";
              middle_emulation = "enabled";
              pointer_accel = "0.25";
            };
          };
          # Fun keybindings
          keybindings = {
            "${modifier}+Q" = "kill";
            "${modifier}+Space" = "exec ${menu}";
            "${modifier}+V" = "exec cliphist list | rofi -dmenu | cliphist decode | wl-copy";
            "${modifier}+M" = "exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -b 'Yes, exit sway' 'swaymsg exit'";
            "${modifier}+L" = "exec loginctl lock-session";
            "${modifier}+W" = "floating toggle";

            # Special Function keys
            "Print" = "exec flameshot gui";
            "XF86MonBrightnessUp" = "exec brightnessctl -s s +5%";
            "XF86MonBrightnessDown" = "exec brightnessctl -s s 5%-";
            "XF86AudioRaiseVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1";
            "XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- --limit 1";
            "XF86AudioMute" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 0%";
            "XF86AudioPlay" = "exec playerctl play-pause";
            "XF86AudioPause" = "exec playerctl pause";
            "XF86AudioNext" = "exec playerctl next";
            "XF86AudioPrev" = "exec playerctl previous";

            # Workspace mods
            "${modifier}+1" = "workspace number 1";
            "${modifier}+2" = "workspace number 2";
            "${modifier}+3" = "workspace number 3";
            "${modifier}+4" = "workspace number 4";
            "${modifier}+5" = "workspace number 5";
            "${modifier}+6" = "workspace number 6";
            "${modifier}+7" = "workspace number 7";
            "${modifier}+8" = "workspace number 8";
            "${modifier}+9" = "workspace number 9";
            "${modifier}+0" = "workspace number 10";
            "${modifier}+Shift+1" = "move container to workspace number 1; workspace number 1";
            "${modifier}+Shift+2" = "move container to workspace number 2; workspace number 2";
            "${modifier}+Shift+3" = "move container to workspace number 3; workspace number 3";
            "${modifier}+Shift+4" = "move container to workspace number 4; workspace number 4";
            "${modifier}+Shift+5" = "move container to workspace number 5; workspace number 5";
            "${modifier}+Shift+6" = "move container to workspace number 6; workspace number 6";
            "${modifier}+Shift+7" = "move container to workspace number 7; workspace number 7";
            "${modifier}+Shift+8" = "move container to workspace number 8; workspace number 8";
            "${modifier}+Shift+9" = "move container to workspace number 9; workspace number 9";
            "${modifier}+Shift+0" = "move container to workspace number 10; workspace number 10";
          };
        };
        # Extra config stuff that didn't have options in Nix
        extraConfig = ''
          default_border pixel
          bindgesture swipe:right workspace prev
          bindgesture swipe:left workspace next
          seat seat0 xcursor_theme catppuccin-mocha-green-cursors 24
        '';
      };
      # Enable kanshi for dynamic monitor configuration!
      services.kanshi = {
        enable = true;
        settings = [
          {
            profile.name = "docked";
            profile.outputs = [
              {
                criteria = "eDP-1";
                position = "1050,0";
                scale = 1.0;
              }
              {
                criteria = "Dell Inc. DELL P2210 U828K953633S";
                transform = "90";
                position = "0,0";
              }
              {
                criteria = "Dell Inc. DELL P2210 U829K04717LI";
                transform = "270";
                position = "3306,0";
              }
            ];
          }
          {
            profile.name = "undocked";
            profile.outputs = [
              {
                criteria = "eDP-1";
                scale = 1.0;
                status = "enable";
              }
            ];
          }
        ];
      };
    };
  };
}
