{pkgs, config, lib, inputs, ... }: let cfg = config.tp.graphics; in {
  options.tp.graphics = {
    kitty = lib.mkEnableOption "Enable Kitty and theming for it";
  };

  config = lib.mkIf cfg.kitty {
    tp.hm.programs.kitty = {
      enable = true;
      font = {
          name = "Fira-Code";
          size = 11;
      };
      themeFile = "Catppuccin-Mocha";
      shellIntegration.enableZshIntegration = true;
    };
  };
}