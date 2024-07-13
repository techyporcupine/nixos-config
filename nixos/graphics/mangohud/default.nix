{pkgs, config, lib, inputs, ... }: let cfg = config.tp.graphics; in {
  options.tp.graphics = {
    mangohud = lib.mkEnableOption "Enable mangohud and config for it";
  };

  config = lib.mkIf cfg.mangohud {
    # Copy configfile for mangohud
    tp.hm.xdg.configFile."mangohud" = {
      enable = true;
      source = ./MangoHud.conf;
      target = "./MangoHud/MangoHud.conf";
    };
  };
}