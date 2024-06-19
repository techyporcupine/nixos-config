{pkgs, ...}: {
  programs.rofi = {
    package = pkgs.rofi-wayland;
    enable = true;
    theme = ./theme.rasi;
    extraConfig = {
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
}