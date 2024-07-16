{ inputs, pkgs, config, lib, ... }: let cfg = config.tp.gaming; in {
  options.tp.gaming = {
    minecraft-server.enable = lib.mkEnableOption "Config for an MC server";
    minecraft-server.broccoli-bloc = lib.mkEnableOption "Config for Broccoli-bloc";
  };

  imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];

  config = lib.mkIf cfg.minecraft-server.enable {
    nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

    services.minecraft-servers = {
      enable = true;
      eula = true;
      servers.broccoli-bloc = lib.mkIf cfg.minecraft-server.broccoli-bloc {
        enable = true;
        autoStart = true;
        openFirewall = true;
        jvmOpts = "-Xms512M -Xmx8192M";
        package = pkgs.paperServers.paper-1_21;
        serverProperties = {
          server-port = 25565;
          difficulty = "normal";
          gamemode = "survival";
          max-players = 20;
          motd = "Broccoli-Bloc Minecraft Server";
          white-list = true;
        };
        #symlinks = {
        #  "plugins" = pkgs.linkFarmFromDrvs "plugins" (builtins.attrValues {
        #    BlueMap = pkgs.fetchurl { url = "https://hangarcdn.papermc.io/plugins/Blue/BlueMap/versions/5.2/PAPER/BlueMap-5.2-paper.jar"; sha512 = "hOn3qsJEExsh1UtYqoiXEpbd25/LEW4NO8hiWD4H5k+qNgkFbqHEozPY8olskDt7K0jHGVKsZv5cZZT3O82xeg=="; };
        #  });
        #};
      };
    };
  };
}