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
    rofi = lib.mkEnableOption "Enable Rofi and theming for it";
  };

  config = lib.mkIf cfg.rofi {
    # Rofi application launcher settings
    tp.hm.programs.rofi = {
      package = pkgs.rofi;
      enable = true;
      # Use custom theme file
      theme = ./theme.rasi;
      extraConfig = {
        # Font for Rofi interface
        font = "Fira Code";
        modi = "drun";
        icon-theme = "Papirus";
        show-icons = true;
        drun-display-format = "{icon} {name}";
        hide-scrollbar = true;
        display-drun = "   Apps ";
        sidebar-mode = true;
      };
    };
  };
}
