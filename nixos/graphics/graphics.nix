# TODO: COMMENTS and fix Nvidia xserver driver thingys
{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.graphics;
in {
  options.tp.graphics = {
    enable = lib.mkEnableOption "TP's graphics stack";
  };

  config = lib.mkIf cfg.enable {
    tp.rtl-sdr.enable = true;

    # Graphical applications
    environment.systemPackages = with pkgs; [
      firefox-bin
      spotify
      xorg.xeyes
      vlc
      helvum
      gimp
      slack
      (vscode-with-extensions.override {
        vscode = vscodium;
        vscodeExtensions = with vscode-extensions; [
          bbenoist.nix
          ms-python.python
          ms-vscode-remote.remote-ssh
          catppuccin.catppuccin-vsc
          catppuccin.catppuccin-vsc-icons
          esbenp.prettier-vscode
          kamadorueda.alejandra
        ];
      })
      zed-editor
      chromium
      stable.super-slicer-beta
      libreoffice-fresh
      audacity
      pavucontrol
      scrcpy
      yubikey-manager-qt
      yubikey-personalization-gui
      webcord
      networkmanagerapplet
    ];

    # Globally enable Wayland in electron apps
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    # FONTS CONFIG
    fonts.packages = with pkgs; [
      rPackages.fontawesome
      iosevka
      inconsolata
      roboto-mono
      fira-code-nerdfont
    ];

    # X11/Wayland Configuration
    services.xserver = {
      enable = true;
    };

    # Enable CUPS to print docs
    services.printing.enable = true;
  };
}
