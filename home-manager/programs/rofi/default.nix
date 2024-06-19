{pkgs, ...}: {
  # Configuration for Rofi, a way to run applications installed on the system
  programs.rofi = {
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
}