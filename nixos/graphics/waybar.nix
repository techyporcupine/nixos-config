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
    waybar = lib.mkEnableOption "Enable waybar and theming for it";
  };

  config = lib.mkIf cfg.waybar {
    environment.systemPackages = with pkgs; [
      lm_sensors
      brightnessctl
      playerctl
    ];
    # Config for waybar
    tp.hm.programs.waybar = {
      package = inputs.waybar.packages.${pkgs.system}.waybar;
      enable = true;
      systemd = {
        enable = false;
        target = "graphical-session.target";
      };
      # CSS style for waybar
      style = ''
        * {
            font-family: iosevka, "Font Awesome 6 Free";
            font-size: 16px;
        }

        window#waybar {
            background-color: @base;
            color: #ffffff;
            border: 2px solid @sky;
            border-radius: 0px;
        }

        /* window#waybar.hidden { */
        /*     opacity: 0.2; */
        /* } */

        button {
            /* Use box-shadow instead of border so the text isn't offset */
            box-shadow: inset 0 -3px transparent;
            /* Avoid rounded borders under each button name */
            border: none;
            border-radius: 0;
        }
        #power-profiles-daemon {
            color: @text;
            background-color: @surface0;
            border-radius: 8px;
            padding: 0 8px;
            font-weight: bold;
            margin: 3px;
        }
        #temperature {
            color: @red;
            background-color: @surface0;
            border-radius: 8px;
            padding: 0 8px;
            font-weight: bold;
            margin: 3px;
        }
        #idle_inhibitor {
            color: @text;
            background-color: @surface0;
            border-radius: 8px;
            padding: 0 8px;
            font-weight: bold;
            margin: 3px;
        }
        #cava {
            color: @sky;
            border-radius: 8px;
            padding: 0 10px;
            font-weight: bold;
            margin: 3px;
        }
        #mpris {
            color: @surface2;
            background-color: @surface0;
            border-radius: 8px;
            padding: 0 10px;
            font-weight: bold;
            margin: 3px;
        }
        #mpd {
            color: @teal;
            border-radius: 8px;
            padding: 0 10px;
            font-weight: bold;
            margin: 3px;
        }
        #clock {
            color: @base;
            background-color: @sky;
            border-radius: 8px;
            padding: 0 10px;
            font-weight: bold;
            margin: 1px;
        }
        #workspaces button {
            padding: 0 0px;
            border-radius: 8px;
            /* background-color: @surface0; */
            color: @green;
            margin: 3px;
            font-weight: bold;
        }
        #workspaces button.focused {
            background-color: @surface0;
        }
        #workspaces button.urgent {
            background-color: @red;
        }
        #backlight {
            color: @sky;
            background-color: @surface0;
            border-radius: 8px;
            padding: 0 10px;
            font-weight: bold;
            margin: 3px;
        }
        #battery {
            color: @sky;
            background-color: @surface0;
            border-radius: 8px;
            padding: 0 10px;
            font-weight: bold;
            margin: 3px;
        }
        #battery.warning{
            color: @peach;
        }
        #battery.critical{
            color: @red;
        }
        #custom-fan {
            color: @red;
            background-color: @surface0;
            border-radius: 8px;
            padding: 0 10px;
            font-weight: bold;
            margin: 3px;
        }
        #custom-cputemp {
            color: @red;
            background-color: @surface0;
            border-radius: 8px;
            padding: 0 10px;
            font-weight: bold;
            margin: 3px;
        }
        #cpu {
            color: @yellow;
            background-color: @surface0;
            border-radius: 8px;
            padding: 0 10px;
            font-weight: bold;
            margin: 3px;
        }
        #memory {
            color: @yellow;
            background-color: @surface0;
            border-radius: 8px;
            padding: 0 10px;
            font-weight: bold;
            margin: 3px;
        }
        #network {
            color: @mauve;
            background-color: @surface0;
            border-radius: 8px;
            padding: 0 10px;
            font-weight: bold;
            margin: 3px;
        }
        #network.disconnected {
            color: #f53c3c;
            border-radius: 8px;
        }
        #pulseaudio {
            color: @text;
            background-color: @surface0;
            border-radius: 8px;
            padding: 0 10px;
            font-weight: bold;
            margin: 3px;
        }
        #pulseaudio.muted {
            color: @text;
            border-radius: 8px;
        }
        #keyboard-state {
            color: @mauve;
            background-color: @surface0;
            border-radius: 8px;
            padding: 0 10px;
            font-weight: bold;
            margin: 3px;
        }
        #tray {
            color: @text;
            background-color: @surface0;
            border-radius: 8px;
            padding: 0 10px;
            font-weight: bold;
            margin: 3px;
        }
        #workspaces {
            margin: 0 4px;
            background-color: transparent;
            font-weight:bold;
            border-radius: 8px;
            color: @mauve;
        }

        @keyframes blink {
            to {
                background-color: #ffffff;
                color: #000000;
            }
        }

        label:focus {
            background-color: #000000;
        }

        /*
        *
        * Catppuccin Mocha palette
        * Maintainer: rubyowo
        *
        */

        @define-color base   #1e1e2e;
        @define-color mantle #181825;
        @define-color crust  #11111b;

        @define-color text     #cdd6f4;
        @define-color subtext0 #a6adc8;
        @define-color subtext1 #bac2de;

        @define-color surface0 #313244;
        @define-color surface1 #45475a;
        @define-color surface2 #585b70;

        @define-color overlay0 #6c7086;
        @define-color overlay1 #7f849c;
        @define-color overlay2 #9399b2;

        @define-color blue      #89b4fa;
        @define-color lavender  #b4befe;
        @define-color sapphire  #74c7ec;
        @define-color sky       #89dceb;
        @define-color teal      #94e2d5;
        @define-color green     #a6e3a1;
        @define-color yellow    #f9e2af;
        @define-color peach     #fab387;
        @define-color maroon    #eba0ac;
        @define-color red       #f38ba8;
        @define-color mauve     #cba6f7;
        @define-color pink      #f5c2e7;
        @define-color flamingo  #f2cdcd;
        @define-color rosewater #f5e0dc;
      '';
      # Normal config for waybar
      settings = [
        {
          "layer" = "top";
          "height" = 34;
          "spacing" = 2;
          "modules-left" = ["sway/workspaces"];
          "modules-center" = ["clock"];
          "modules-right" = ["power-profiles-daemon" "idle_inhibitor" "tray" "pulseaudio" "backlight" "network" "temperature" "cpu" "memory" "battery"];
          "margin" = "6px 6px 0px 6px";
          "power-profiles-daemon" = {
            "format" = "{icon}";
            "tooltip-format" = "Power profile: {profile}\nDriver: {driver}";
            "tooltip" = true;
            "format-icons" = {
              "default" = "";
              "performance" = "";
              "balanced" = "";
              "power-saver" = "";
            };
          };
          "temperature" = {
            "thermal-zone" = 3;
            "interval" = 7;
            "format" = "{temperatureC}°C ";
          };
          "idle_inhibitor" = {
            "format" = "{icon}";
            "format-icons" = {
              "activated" = "";
              "deactivated" = "";
            };
          };
          "cava" = {
            "framerate" = 60;
            "sensitivity" = 1;
            "bars" = 24;
            "lower_cutoff_freq" = 50;
            "higher_cutoff_freq" = 10000;
            "method" = "pipewire";
            "source" = "auto";
            "stereo" = true;
            "reverse" = false;
            "bar_delimiter" = 0;
            "noise_reduction" = 0.77;
            "input_delay" = 2;
            "format-icons" = ["▁" "▂" "▃" "▄" "▅" "▆" "▇" "█"];
            "hide_on_silence" = true;
          };
          "mpris" = {
            "format" = "{player_icon} {title} <small>[{position}/{length}]</small>";
            "format-paused" = "{status_icon} <i>{title} <small>[{position}/{length}]</small></i>";
            "interval" = 1;
            "title-len" = 46;
            "player-icons" = {
              "default" = "▶";
              "mpv" = "🎵";
            };
            "status-icons" = {
              "paused" = "⏸";
            };
            # "ignored-players"= ["firefox"];
          };
          "clock" = {
            "format" = "{:%H:%M:%S}";
            "tooltip-format" = "{:%Y %B}";
            "format-alt" = "{:%Y-%m-%d}";
            "interval" = 1;
          };
          "custom/fan" = {
            "exec" = "sensors | awk '/Processor Fan:/ {print $3,$4}'";
            "interval" = 3;
          };
          "custom/cputemp" = {
            "exec" = "sensors | awk '/CPU:/ {print $2,$3}' | cut -c 2-8";
            "interval" = 3;
          };
          "cpu" = {
            "format" = "{usage}% ";
            "tooltip" = false;
          };
          "memory" = {
            "format" = "{}% ";
          };
          "backlight" = {
            "format" = "{percent}% ";
          };
          "battery" = {
            "states" = {
              "warning" = 25;
              "critical" = 10;
            };
            "format" = "{capacity}% {icon}";
            "format-charging" = "{capacity}% ";
            "format-plugged" = "{capacity}% ";
            "format-alt" = "{time} {icon}";
            "format-icons" = ["" "" "" "" ""];
          };
          "tray" = {
            "icon-size" = 14;
            "spacing" = 5;
          };
          "network" = {
            "format-wifi" = "{essid} ({signalStrength}%) ";
            "format-ethernet" = "{ipaddr} ";
            "tooltip-format" = "{ifname} via {gwaddr} ";
            "format-linked" = "{ifname} (No IP) ";
            "format-disconnected" = "Disconnected ";
            "format-alt" = "{ifname}= {ipaddr}";
          };
          "wireplumber" = {
            "format" = "{volume}% {icon}";
            "format-muted" = "";
            "on-click" = "helvum";
            "format-icons" = ["" "" ""];
          };
        }
      ];
    };
  };
}
