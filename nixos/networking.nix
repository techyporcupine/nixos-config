{pkgs, config, lib, ... }: let cfg = config.tp.networking; in {
  options.tp.networking = {
    enable = lib.mkEnableOption "TP's network stack";
    tailscale.client.enable = lib.mkEnableOption "Tailscale";
    avahi.enable = lib.mkEnableOption "Avahi";
  };

  config = lib.mkIf cfg.enable {
    networking = {
      networkmanager.enable = true; # Enable networking via networkmanager
    };
    services.tailscale = lib.mkIf cfg.tailscale.client.enable {
      enable = true;
      useRoutingFeatures = "client";
      extraUpFlags = "--accept-routes --exit-node=nixserve";
    };
    services.avahi = lib.mkIf cfg.avahi.enable {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };
}