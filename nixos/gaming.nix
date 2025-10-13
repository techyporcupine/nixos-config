# Gaming configuration module
# Enables Steam, Gamescope, GameMode, and various emulators
{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.tp.gaming;
in {
  options.tp.gaming = {
    enable = lib.mkEnableOption "TP's gaming configuration";
    # Separate option to control graphical programs (useful for headless systems)
    graphical = lib.mkEnableOption "gaming programs that are graphical";
  };

  config = lib.mkIf cfg.enable {
    # PROGRAMS CONFIG
    programs = lib.mkIf cfg.graphical {
      # Gamescope: Valve's micro-compositor for gaming (better performance/control)
      gamescope.enable = true;

      # GameMode: Feral Interactive's optimization daemon (CPU governor, process priority)
      gamemode.enable = true;

      # Steam with automatic FHS environment setup
      steam.enable = true;
    };

    environment.systemPackages = with pkgs;
      lib.mkIf cfg.graphical [
        mangohud
        jre17_minimal
        prismlauncher
        dolphin-emu
        cemu
      ];
  };
}
