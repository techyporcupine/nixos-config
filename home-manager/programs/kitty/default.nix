{pkgs, ...}: {
  # Config for the kitty terminal emulator
  programs.kitty = {
    enable = true;
    font = {
        name = "Fira-Code";
        size = 11;
    };
    theme = "Catppuccin-Mocha";
    shellIntegration.enableZshIntegration = true;
  };
}