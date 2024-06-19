{pkgs, config, lib, ... }: let cfg = config.tp.gaming; in {
  options.tp.gaming = {
    enable = lib.mkEnableOption "TP's gaming configuration";
  };

  config = lib.mkIf cfg.enable {
    # PROGRAMS CONFIG
    programs = {
      # Enable Valve's Gamescope
      gamescope.enable = true;

      gamemode.enable = true;
    };

    environment.systemPackages = with pkgs; [
      mangohud
      jre17_minimal
      prismlauncher
      dolphin-emu
    ];
  };
}