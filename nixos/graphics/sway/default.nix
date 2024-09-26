{pkgs, config, lib, inputs, ... }: let cfg = config.tp.graphics; in {
  options.tp.graphics = {
    sway = lib.mkEnableOption "Enable Sway and all things required for it to work";
  };

  config = lib.mkIf cfg.sway {
    # Enable the gnome-keyring secrets vault. 
    # Will be exposed through DBus to programs willing to store secrets.
    services.gnome.gnome-keyring.enable = true;

    security.polkit.enable = true;

    # enable sway window manager
    programs.sway = {
        enable = true;
        package = pkgs.swayfx;
    };

    tp.hm = {
      wayland.windowManager.sway = {
        enable = true;
        package = pkgs.swayfx;
        checkConfig = false;
        config = rec {
          modifier = "Mod4";
          # Declare display outputs
          output = {
            eDP-1 = {
              scale = "1";
            };
          };
          # Use kitty as default terminal
          terminal = "kitty"; 
          startup = [
            # Launch some applications on start
            {command = "firefox";}
            {command = "hyprpaper";}
            {command = "hypridle";}
            {command = "swaync";}
            {command = "wl-paste --watch cliphist store";}
          ];
          # Set command used to launch dmenu
          menu = "zsh -c 'rofi -show drun'";
          # Set status bar used
          bars = [
            {command = "waybar";}
          ];
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
            "${modifier}+C" = "kill";
            "${modifier}+R" = "exec ${menu}";
            "${modifier}+V" = "exec cliphist list | rofi -dmenu | cliphist decode | wl-copy";
            "${modifier}+M" = "exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -b 'Yes, exit sway' 'swaymsg exit'";
            "${modifier}+N" = "exec swaync-client -t -sw";
            "${modifier}+L" = "exec loginctl lock-session";
            "${modifier}+W" = "floating toggle";
            "Print" = "exec grimshot copy area";
            "XF86MonBrightnessUp" = "exec brightnessctl -s s +5%";
            "XF86MonBrightnessDown" = "exec brightnessctl -s s 5%-";
            "XF86AudioRaiseVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1";
            "XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- --limit 1";


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
            "${modifier}+Shift+1" = "move container to workspace number 1; workspace number 1";
            "${modifier}+Shift+2" = "move container to workspace number 2; workspace number 2";
            "${modifier}+Shift+3" = "move container to workspace number 3; workspace number 3";
            "${modifier}+Shift+4" = "move container to workspace number 4; workspace number 4";
            "${modifier}+Shift+5" = "move container to workspace number 5; workspace number 5";
            "${modifier}+Shift+6" = "move container to workspace number 6; workspace number 6";
            "${modifier}+Shift+7" = "move container to workspace number 7; workspace number 7";
            "${modifier}+Shift+8" = "move container to workspace number 8; workspace number 8";
            "${modifier}+Shift+9" = "move container to workspace number 9; workspace number 9";
          };
        }; 
        # Extra config stuff that didn't have options in Nix
        extraConfig = ''
          default_border pixel
          corner_radius 10
          bindgesture swipe:right workspace prev
          bindgesture swipe:left workspace next
          seat seat0 xcursor_theme catppuccin-mocha-green-cursors 24
        '';
      };
    };
  };
}