{inputs, config, pkgs, ... }:

{
  home.packages = [ 
    pkgs.swaynotificationcenter
    pkgs.hyprpaper
    inputs.hypridle.packages.${pkgs.system}.hypridle
    pkgs.hyprlock
    pkgs.hyprpicker
    pkgs.sway-contrib.grimshot
    pkgs.cliphist
    pkgs.wl-clipboard
  ];

  xdg.configFile."hyprpaper" = {
    enable = true;
    source = ./hyprpaper.conf;
    target = "hypr/hyprpaper.conf";
  };
  xdg.configFile."hypridle" = {
    enable = true;
    source = ./hypridle.conf;
    target = "hypr/hypridle.conf";
  };
  xdg.configFile."hyprlock" = {
    enable = true;
    source = ./hyprlock.conf;
    target = "hypr/hyprlock.conf";
  };
  xdg.configFile."wallpapers" = {
    enable = true;
    source = ./wallpapers;
    target = "hypr/wallpapers";
  };
  wayland.windowManager.hyprland = {
    settings = {
      # Configuration for monitors
      monitor = [
        # https://wiki.hyprland.org/Configuring/Monitors/
        "eDP-1,1920x1080@60,0x0,1"
        "HDMI-A-1,1920x1080@120,1920x0,1" # 1080 high refresh conf
        #"monitor=,preferred,auto,1" # Everything config
      ];
      # Commands to exec on launch
      exec-once = [
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "swaync"
        "waybar"
        "hyprpaper"
        "hypridle"
        "udiskie"
        "wl-paste --watch cliphist store"
        "hyprctl setcursor catppuccin-mocha-green-cursors 24"
        "firefox"
      ];
      # Disable hardware cursors
      cursor.no_hardware_cursors = true;
      # Input devices configuration
      input = {
        kb_layout = "us";
        kb_model = "latitude";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = "no";
          disable_while_typing = false;
        };
        sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
      };
      # Config under the general section
      general = {
        gaps_in = 6;
        gaps_out = 6;
        border_size = 2;
        "col.active_border" = "rgba(89dcebff) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        layout = "dwindle";
      };
      # Decoration configuration
      decoration = {
        blur = {
          enabled = true;
          size = 8;
          passes = 1;
          new_optimizations = "on";
          ignore_opacity = true;
        };
        rounding = 10;
        inactive_opacity = .85;
        drop_shadow = "yes";
        shadow_range = 4;
        shadow_render_power = 3;
        "col.shadow" = "rgba(1a1a1aee)";
      };
      # Animations configuration
      animations = {
        # https://wiki.hyprland.org/Configuring/Animations/ 
        enabled = "yes";
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 4, default"
        ];
      };
      # Configuration for the dwindle layout
      dwindle = {
        pseudotile = "yes";
        preserve_split = "yes";
      };
      gestures = {
        workspace_swipe = "yes";
      };
      misc = {
        disable_hyprland_logo = true;
        vfr = true;
      };
      "$mainMod" = "SUPER";
      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];
      binde = [
        ", XF86MonBrightnessUp, exec, brightnessctl -s s +5%"
        ", XF86MonBrightnessDown, exec, brightnessctl -s s 5%-"
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- --limit 1"   
      ];
      bind = [
        "$mainMod, C, killactive," 
        "$mainMod, M, exit, "
        "$mainMod, E, exec, nautilus"
        "$mainMod, W, togglefloating, "
        "$mainMod, R, exec, rofi -show drun"
        "$mainMod, J, togglesplit," # dwindle
        "$mainMod, N, exec, swaync-client -t -sw"
        "$mainMod, L, exec, loginctl lock-session"
        "$mainMod, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy"

        ", XF86AudioMute, exec, amixer sset Master 0"
        ", Print, exec, grimshot copy area"

        # Scroll through existing workspaces with mainMod + scroll
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
      ]
      ++ (
        # workspaces
        # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
        builtins.concatLists (builtins.genList (
            x: let
              ws = let
                c = (x + 1) / 10;
              in
                builtins.toString (x + 1 - (c * 10));
            in [
              "$mainMod, ${ws}, workspace, ${toString (x + 1)}"
              "$mainMod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
            ]
          )
          10)
      );
    };
  };
}
