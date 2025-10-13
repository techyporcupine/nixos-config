# Nix package manager configuration module
# Configures flakes, substituters, store optimization, and nh helper tool
{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.nix;
in {
  options.tp.nix = {
    enable = lib.mkEnableOption "TP's nix config";
  };

  config = lib.mkIf cfg.enable {
    # NIX CONFIG
    nix = {
      # Use latest Nix version (gets newest features/fixes)
      package = pkgs.nixVersions.latest;
      # Disable legacy channels (using flakes instead for reproducibility)
      channel.enable = false;

      settings = {
        # Allow root to use binary caches without confirmation
        trusted-users = ["root"];
        # Automatically deduplicate identical store paths (saves disk space)
        auto-optimise-store = true;

        # Enable flakes and new 'nix' command (required for modern workflows)
        experimental-features = ["nix-command" "flakes"];

        # Binary caches for Hyprland and AI packages (speeds up builds)
        trusted-substituters = ["https://hyprland.cachix.org" "https://ai.cachix.org"];
        # Public keys to verify binary cache signatures (security)
        trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="];
      };
    };

    # nh: NixOS helper tool (simpler commands like 'nh os switch')
    programs.nh = {
      enable = true;
      clean.enable = true;
      # Run garbage collection daily
      clean.dates = "daily";
      # Keep only last 2 days of generations (prevents disk bloat)
      clean.extraArgs = "--keep-since 2d";
    };

    # Allow proprietary packages (Steam, Discord, etc.)
    nixpkgs.config.allowUnfree = true;
  };
}
