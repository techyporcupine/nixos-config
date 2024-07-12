# Home manager config file

{ inputs, lib, config, pkgs, ... }: {
  # You can import other home-manager modules here
  imports = [
    ./programs
  ];
}
