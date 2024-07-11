{pkgs, config, lib, inputs, ... }: let cfg = config.tp.graphics; in {
  options.tp.graphics = {
    kitty = lib.mkEnableOption "Enable Kitty and theming for it";
  };

  config = lib.mkIf cfg.enable {
    tp.hm.programs.kitty = lib.mkIf cfg.kitty {
      enable = true;
      font = {
          name = "Fira-Code";
          size = 11;
      };
      theme = "Catppuccin-Mocha";
      shellIntegration.enableZshIntegration = true;
    };
  };
}