{pkgs, config, lib, ... }: let cfg = config.tp.user; in {
  options.tp.user = {
    enable = lib.mkEnableOption "TP's user specific configuration";
  };

  config = lib.mkIf cfg.enable {
    # USER CONFIG
    users.users.techyporcupine = {
      isNormalUser = true;
      description = "Caleb";
      extraGroups = [ "networkmanager" "wheel" "plugdev" "video" "audio" "dialout" ];
      shell = pkgs.zsh;
      initialPassword = "initialPassword";
    };
    # Enable Zsh, THIS IS NESSECERY to get nix directories in zsh's path.
    programs.zsh.enable = true;
  };
}