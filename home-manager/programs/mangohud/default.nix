{ config, pkgs, ... }:

{
  # Copy configfile for mangohud
  xdg.configFile."mangohud" = {
    enable = true;
    source = ./MangoHud.conf;
    target = "./MangoHud/MangoHud.conf";
  };
}