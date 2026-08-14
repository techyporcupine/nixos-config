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
    wofi = lib.mkEnableOption "Enable Wofi and theming for it";
  };

  config = lib.mkIf cfg.wofi {
    tp.hm.programs.wofi = {
      enable = true;
      package = pkgs.wofi;

      settings = {
        show = "drun";
        prompt = "  Apps ";
        allow_images = true;
        allow_markup = true;
      };

      # Read the downloaded Catppuccin CSS and append your custom overrides
      style = ''
        ${builtins.readFile ./mocha.css}

        * {
          font-family: "Fira Code";
        }
        #scroll {
          margin-right: -15px;
        }
      '';
    };
  };
}
