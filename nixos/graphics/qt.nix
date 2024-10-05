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
    qt = lib.mkEnableOption "Enable some qt settings";
  };

  config = lib.mkIf cfg.qt {
    # TODO: Figure out what this is doing here and if it's really needed and why.
    tp.hm.qt = {
      enable = true;
      style.package = pkgs.lightly-qt;
      style.name = "Lightly";
    };
  };
}
