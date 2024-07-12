{config, lib, pkgs, ... }:
{
  home.packages = with pkgs; [ 
    catppuccin-cursors.mochaGreen
    gnome.adwaita-icon-theme
  ];
  # set some options in dconf cus they didnt take effect otherwise
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      cursor-theme = "catppuccin-mocha-green-cursors";
    };
  };

  # Other GTK settings
  gtk = {
    enable = true;
    theme = {
      name = "Catppuccin-Mocha-Standard-Green-Dark";
      package = pkgs.stable.catppuccin-gtk.override {
        accents = [ "green" ];
        size = "standard";
        variant = "mocha";
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    font = {
      name = "FiraCode Nerd Font";
      size = 10;
    };
  };
}