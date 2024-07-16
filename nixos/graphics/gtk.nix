{ pkgs, config, lib, inputs, ... }: let cfg = config.tp.graphics; in {
  options.tp.graphics = {
    gtk = lib.mkEnableOption "Enable gtk theming";
  };

  config = lib.mkIf cfg.gtk {
    environment.systemPackages = with pkgs; [
      catppuccin-cursors.mochaGreen
      gnome.adwaita-icon-theme
    ];
    tp.hm = {
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
        catppuccin = {
          enable = true;
          flavor = "mocha";
          accent = "green";
          size = "standard";
          tweaks = [ "normal" ];
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
    };
  };
}