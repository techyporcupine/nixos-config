{ inputs, pkgs, config, lib, ... }: let cfg = config.tp.gaming; in {
  options.tp.gaming = {
    minecraft-server.enable = lib.mkEnableOption "Config for an MC server";
    minecraft-server.broccoli-bloc = lib.mkEnableOption "Config for Broccoli-bloc";
  };

  config = lib.mkIf cfg.minecraft-server.enable {
    imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];
    nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

    services.minecraft-servers.servers = {
      enable = true;
      eula = true;
      broccoli-bloc = lib.mkIf cfg.minecraft-server.broccoli-bloc {
        enable = true;
        autoStart = true;
        openFirewall = true;
        package = pkgs.paperServers.paper-1_21_66;
        serverProperties = {
          server-port = 25565;
          difficulty = "normal";
          gamemode = "survival";
          max-players = 20;
          motd = "Broccoli-Bloc Minecraft Server";
          white-list = false; # TODO: ADJUST THIS WHEN PUBLIC
        };
      };
    };
  };
}