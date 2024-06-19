{ config, pkgs, ... }:

{
  home.packages = with pkgs; [ 
    zsh-powerlevel10k
  ];
  programs = {
    zsh = {
      enable = true;
      initExtra = ''
        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
      ''; 
      oh-my-zsh = {
        enable = true;
        plugins = [
          "git"
          "sudo"
        ];
      };
      shellAliases = {
        c = "clear";
      };
      autosuggestion.enable = true;
      enableCompletion = true;
      syntaxHighlighting.enable = true;
    };
  };
  xdg.configFile."powerlevel10k" = {
    enable = true;
    source = ./.p10k.zsh;
    target = "../.p10k.zsh";
  };
}