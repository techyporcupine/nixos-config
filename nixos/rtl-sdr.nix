# RTL-SDR configuration module
# Enables RTL-SDR hardware support and installs radio software (GQRX, GNU Radio, etc.)
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
    # Enable RTL-SDR USB dongle support (sets udev rules, blacklists DVB drivers)
    hardware.rtl-sdr = {
      enable = true;
    };

    environment.systemPackages = [
      pkgs.gqrx
      pkgs.gnuradio
      pkgs.noaa-apt
      pkgs.stable.gpredict
      pkgs.gqrx
      #pkgs.master.rtl_433
      pkgs.rtlamr
    ];
  };
}
