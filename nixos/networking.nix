{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.tp.networking;
in {
  options.tp.networking = {
    enable = lib.mkEnableOption "TP's network stack";
    avahi = lib.mkEnableOption "Avahi";
  };

  config = lib.mkIf cfg.enable {
    networking = {
      networkmanager.enable = true; # Enable networking via networkmanager
      firewall = {
        extraCommands = "iptables -I nixos-fw -s 10.0.0.148 -p udp -j nixos-fw-accept"; # hdhomerun
      };
    };
    # Enable avahi for mdns reflection
    services.avahi = lib.mkIf cfg.avahi {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    environment.systemPackages = with pkgs; [
      wirelesstools
      inetutils
      dig
    ];
  };
}
