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
    wofi = lib.mkEnableOption "Enable Wofi and Catppuccin theming for it";
  };

  config = lib.mkIf cfg.wofi {
    # Wofi application launcher settings
    tp.hm.programs.wofi = {
      enable = true;
      package = pkgs.wofi;

      settings = {
        show = "drun";
        prompt = "  Apps ";
        allow_images = true;
        allow_markup = true;
      };

      # Catppuccin handles the colors, but if you still want to force
      # "Fira Code" and hide the scrollbar like your Rofi config,
      # you can append those specific rules here.
      style = ''
        * {
          font-family: "Fira Code";
        }
        #scroll {
          margin-right: -15px;
        }
      '';
    };

    # Enable Catppuccin theming specifically for Wofi
    tp.hm.catppuccin.wofi.enable = true;

    # If you haven't already defined your global flavor in your Home Manager root,
    # you can uncomment the line below to set it:
    # tp.hm.catppuccin.flavor = "mocha";
  };
}
