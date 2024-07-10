{pkgs, config, lib, options, inputs, ... }:{
  options.tp.hm = lib.mkOption {
    description = "The `home-manager` configuration of the primary user";
    apply = lib.const config.home-manager.users.${config.tp.username};
  };
  options.tp.username = lib.mkOption {
    type = with lib.types; nullOr str; # FIXME: setting this to null may break things
    default = "techyporcupine";
    # default = null;
    description = "The username of the primary user";
  };
  options.tp.fullName = lib.mkOption {
    type = with lib.types; nullOr str; # FIXME: setting this to null may break things
    default = "Caleb";
    # default = null;
    description = "The full name of the primary user";
  };

  config = lib.mkIf (config.tp.username != null) {
    users.users.${config.tp.username} = {
      isNormalUser = true;
      description = "${config.tp.fullName}";
      extraGroups = [ "networkmanager" "wheel" "plugdev" "video" "audio" "dialout" "fuse" ];
      shell = pkgs.zsh;
      initialPassword = "initialPassword";
    };
    # Enable Zsh, THIS IS NESSECERY to get nix directories in zsh's path.
    programs.zsh.enable = true;
    # Allow other users to do fuse mounts
    programs.fuse.userAllowOther = true;
    
    home-manager.users.${config.tp.username}.imports = options.tp.hm.definitions;
  };
}