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
    kitty = lib.mkEnableOption "Enable Kitty and theming for it";
  };

  config = lib.mkIf cfg.kitty {
    tp.hm.programs.kitty = {
      enable = true;
      font = {
        name = "Fira-Code";
        size = 11;
      };
      keybindings = {
        "alt+1" = "goto_tab 1";
        "alt+2" = "goto_tab 2";
        "alt+3" = "goto_tab 3";
        "alt+4" = "goto_tab 4";
        "alt+5" = "goto_tab 5";
        "alt+6" = "goto_tab 6";
        "alt+7" = "goto_tab 7";
        "alt+8" = "goto_tab 8";
        "alt+9" = "goto_tab 9";
        "alt+10" = "goto_tab 10";
      };
      themeFile = "Catppuccin-Mocha";
      shellIntegration.enableZshIntegration = true;
    };
  };
}
