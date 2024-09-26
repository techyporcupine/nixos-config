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
        package = null;
        wrapperFeatures.gtk = true;
    };

    tp.hm = {
      wayland.windowManager.sway = {
        enable = true;
        config = rec {
          modifier = "Mod4";
          # Use kitty as default terminal
          terminal = "kitty"; 
          startup = [
            # Launch Firefox on start
            {command = "firefox";}
          ];
        };
      };
    }
  };
}