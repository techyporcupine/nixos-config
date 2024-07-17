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
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHWH6pEu0TpKviWyn/MaUF5dHdX9CE0K3LUTRHFWCqWb"
      ];
    };

    # Enable Zsh, THIS IS NESSECERY to get nix directories in zsh's path.
    programs.zsh.enable = true;
    
    # Allow other users to do fuse mounts
    programs.fuse.userAllowOther = true;
    
    home-manager.users.${config.tp.username}.imports = options.tp.hm.definitions;

    tp.hm.home = {
      username = "${config.tp.username}";
      homeDirectory = "/home/${config.tp.username}";
    };

    tp.hm.programs.git = lib.mkIf (config.tp.hm.programs.git.userName != null) {
      enable = true;
      signing = {
        signByDefault = true;
        key = "~/.ssh/id_ed25519";
      };
      extraConfig = {
        gpg = {
          format = "ssh";
        };
      };
    };
  };
}