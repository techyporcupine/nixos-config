# TODO: COMMENTS
{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.tp.rtl-sdr;
in {
  options.tp.rtl-sdr = {
    enable = lib.mkEnableOption "TP's sdr stack";
  };

  config = lib.mkIf cfg.enable {
    #RTL-SDR config
    hardware.rtl-sdr = {
      enable = true;
    };
    environment.systemPackages = [
      pkgs.gqrx
      pkgs.gnuradio
      pkgs.noaa-apt
      pkgs.gpredict
      pkgs.gqrx
      pkgs.rtl_433
    ];
  };
}
