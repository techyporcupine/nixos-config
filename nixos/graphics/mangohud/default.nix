# MangoHud performance overlay configuration
# Copies MangoHud configuration file for gaming performance monitoring
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
    mangohud = lib.mkEnableOption "Enable mangohud and config for it";
  };

  config = lib.mkIf cfg.mangohud {
    # Install MangoHud configuration file
    tp.hm.xdg.configFile."mangohud" = {
      enable = true;
      # Source configuration from MangoHud.conf
      source = ./MangoHud.conf;
      # Install to XDG config directory
      target = "./MangoHud/MangoHud.conf";
    };
  };
}
