{ config, pkgs, ... }:

{
  home.packages = with pkgs; [ 
    zsh-powerlevel10k
  ];
  programs = {
    zsh = {
      enable = true;
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
    starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        format = "$directory$character$git_branch$git_status";
        right_format = "$status$cmd_duration";
        character = {
          success_symbol = "[❯](blue)";
          error_symbol = "[❯](red)";
        };
        status = {
          disabled = false;
          format = "[$symbol]($style)";
          symbol = "[✘ ](red)";
          success_symbol = "[✔ ](green)";
        };
        git_branch = {
          format = "[$branch]($style) ";
          style = "bold green";
        };
        directory = {
          style = "blue";
          truncation_length = 1;
          truncation_symbol = "";
          fish_style_pwd_dir_length = 1;
        };
        cmd_duration = {
          min_time = 0;        
        };
      };
    };
  };
}