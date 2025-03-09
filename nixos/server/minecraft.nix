{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.tp.server.minecraft;
in {
  options.tp.server = {
    minecraft.enable = lib.mkEnableOption "Config for an MC server";
    minecraft.broccoli-bloc = lib.mkEnableOption "Config for Broccoli-bloc";
  };

  imports = [inputs.nix-minecraft.nixosModules.minecraft-servers];

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [inputs.nix-minecraft.overlay];

    networking.firewall.interfaces."ens18" = {
      allowedTCPPorts = [
        # Minecraft
        25565
      ];
      allowedUDPPorts = [
        # Minecraft
        25565
        19132
      ];
    };

    services.minecraft-servers = {
      enable = true;
      eula = true;
      servers.broccoli-bloc = lib.mkIf cfg.broccoli-bloc {
        enable = true;
        autoStart = true;
        openFirewall = true;
        jvmOpts = "-Xms512M -Xmx8192M";
        package = pkgs.paperServers.paper-1_21_4;
        serverProperties = {
          server-port = 25565;
          difficulty = "normal";
          gamemode = "survival";
          max-players = 20;
          motd = "Broccoli-Bloc Minecraft Server";
          white-list = true;
          enforce-secure-profile = false;
          spawn-protection = 0;
          view-distance = 14;
        };
      };
    };
  };
}
