{
  pkgs,
  config,
  lib,
  inputs,
  catppuccin,
  ...
}: let
  cfg = config.tp.graphics;
in {
  options.tp.graphics = {
    mako = lib.mkEnableOption "Enable mako notification daemon";
  };

  config = lib.mkIf cfg.mako {
    tp.hm = {
      services.mako = {
        enable = true;
        settings = {
          actions = true;
          anchor = "top-right";
          border-radius = 0;
          default-timeout = 8000;
          icons = true;
          ignore-timeout = false;
        };
      };
      catppuccin.mako = {
        enable = true;
        accent = "green";
        flavor = "mocha";
      };
    };
  };
}
