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
    nvidia = lib.mkEnableOption "TP's graphics stack";
  };

  config =
    lib.mkIf cfg.enable {
    };
}
