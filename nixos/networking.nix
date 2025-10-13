# Network configuration module
# Configures NetworkManager, firewall rules, Avahi mDNS, and network utilities
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
      # NetworkManager for easier WiFi/network management (vs manual ifconfig)
      networkmanager.enable = true;
    };

    # Avahi: mDNS/DNS-SD implementation (discovers .local hostnames)
    services.avahi = lib.mkIf cfg.avahi {
      enable = true;
      # Enable mDNS name resolution in NSS (allows resolving .local addresses)
      nssmdns4 = true;
      # Open firewall for mDNS traffic (UDP port 5353)
      openFirewall = true;
    };

    environment.systemPackages = with pkgs; [
      wirelesstools
      inetutils
      dig
    ];
  };
}
