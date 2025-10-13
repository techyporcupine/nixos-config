# Main NixOS configuration module aggregator
# Imports all system configuration modules
{
  imports = [
    ./networking.nix
    ./disks.nix
    ./gaming.nix
    ./server
    ./misc-nix.nix
    ./misc-system.nix
    ./rtl-sdr.nix
    ./user.nix
    ./graphics
  ];
}
