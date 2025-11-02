# User configuration module
# Defines primary user account, groups, shell, and home-manager integration
{
  pkgs,
  config,
  lib,
  options,
  inputs,
  ...
}: {
  # Shorthand option to access home-manager config (tp.hm.*)
  options.tp.hm = lib.mkOption {
    description = "The `home-manager` configuration of the primary user";
    apply = lib.const config.home-manager.users.${config.tp.username};
  };

  options.tp.username = lib.mkOption {
    type = with lib.types; nullOr str; # FIXME: setting this to null may break things
    default = "techyporcupine";
    description = "The username of the primary user";
  };

  options.tp.fullName = lib.mkOption {
    type = with lib.types; nullOr str; # FIXME: setting this to null may break things
    default = "Caleb";
    description = "The full name of the primary user";
  };

  config = lib.mkIf (config.tp.username != null) {
    users.users.${config.tp.username} = {
      isNormalUser = true;
      description = "${config.tp.fullName}";
      # Groups grant permissions: wheel=sudo, plugdev=USB, video=GPU, dialout=serial, libvirtd/kvm=VMs
      extraGroups = ["networkmanager" "wheel" "plugdev" "video" "audio" "dialout" "fuse" "libvirtd" "kvm"];
      shell = pkgs.zsh;
      # Temporary password (should be changed on first login)
      initialPassword = "initialPassword";
      # SSH public key for passwordless login
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHWH6pEu0TpKviWyn/MaUF5dHdX9CE0K3LUTRHFWCqWb"
      ];
    };

    # Enable Zsh system-wide (required for proper PATH with Nix packages)
    programs.zsh.enable = true;

    # Allow non-root users to mount FUSE filesystems with allow_other option
    programs.fuse.userAllowOther = true;

    # Import home-manager configuration definitions
    home-manager.users.${config.tp.username}.imports = options.tp.hm.definitions;

    tp.hm.home = {
      username = "${config.tp.username}";
      homeDirectory = "/home/${config.tp.username}";
    };

    # Configure Git to sign commits with SSH key (instead of GPG)
    tp.hm.programs.git = lib.mkIf (config.tp.hm.programs.git.settings.user.name != null) {
      enable = true;
      signing = {
        signByDefault = true;
        key = "~/.ssh/id_ed25519";
      };
      extraConfig = {
        gpg = {
          # Use SSH format instead of GPG for commit signing
          format = "ssh";
        };
      };
    };
  };
}
