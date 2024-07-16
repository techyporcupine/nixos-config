{pkgs, config, lib, ... }: let cfg = config.tp.gaming; in {
  options.tp.gaming = {
    enable = lib.mkEnableOption "TP's gaming configuration";
    graphical = lib.mkEnableOption "gaming programs that are graphical";
  };

  config = lib.mkIf cfg.enable {
    # PROGRAMS CONFIG
    programs = lib.mkIf cfg.graphical {
      # Enable Valve's Gamescope
      gamescope.enable = true;

      gamemode.enable = true;
    };

    environment.systemPackages = with pkgs; lib.mkIf cfg.graphical [
      mangohud
      jre17_minimal
      prismlauncher
      dolphin-emu
      heroic
    ];
  };
}