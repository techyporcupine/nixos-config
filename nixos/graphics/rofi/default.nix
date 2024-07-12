{pkgs, config, lib, inputs, ... }: let cfg = config.tp.graphics; in {
  options.tp.graphics = {
    rofi = lib.mkEnableOption "Enable Rofi and theming for it";
  };

  config = lib.mkIf cfg.rofi {
    # Configuration for Rofi, a way to run applications installed on the system
    tp.hm.programs.rofi = {
    package = pkgs.rofi-wayland;
    enable = true;
    theme = ./theme.rasi;
    extraConfig = {
      # TODO: How does this font get defined and stuff, it doesn't seem active
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