{pkgs, config, lib, inputs, ... }: let cfg = config.tp.nix; in {
  options.tp.nix = {
    enable = lib.mkEnableOption "TP's nix config";
  };

  config = lib.mkIf cfg.enable {
    # NIX CONFIG
    nix = {
      package = pkgs.nixVersions.latest;
      # Random Nix Settings
      settings = {
        trusted-users = [ "root" ];
        auto-optimise-store = true;

        experimental-features = [ "nix-command" "flakes" ];

        trusted-substituters = ["https://hyprland.cachix.org" "https://ai.cachix.org"];
        trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="];
      };
    };

    programs.nh = {
      enable = true;
      clean.enable = true;
      clean.dates = "daily";
      clean.extraArgs = "--keep-since 2d";
    };

    # Allow unfree packages
    nixpkgs.config.allowUnfree = true;
  };
}