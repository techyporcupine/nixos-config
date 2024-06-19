{ config, pkgs, ... }:

{
    xdg.configFile."mangohud" = {
    enable = true;
    source = ./MangoHud.conf;
    target = "./MangoHud/MangoHud.conf";
  };
}