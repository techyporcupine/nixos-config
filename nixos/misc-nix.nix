{pkgs, config, lib, inputs, ... }: let cfg = config.tp.nix; in {
  options.tp.nix = {
    enable = lib.mkEnableOption "TP's nix config";
  };

  config = lib.mkIf cfg.enable {
    # NIX CONFIG
    nix = {
      package = pkgs.nixVersions.latest;
      # Garbage Collection config
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
        persistent = true;
      };

      # Random Nix Settings
      settings = {
        trusted-users = [ "root" ];
        auto-optimise-store = true;

        nix-path = "nixpkgs=${inputs.nixpkgs}";

        experimental-features = [ "nix-command" "flakes" ];

        substituters = ["https://hyprland.cachix.org"];
        trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
      };
    };

    # Allow unfree packages
    nixpkgs.config.allowUnfree = true;
  };
}