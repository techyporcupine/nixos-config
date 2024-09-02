## Techyporcupine's Workstation NixOS Config

Repo that has the configuration for a nice NixOS setup using [nixos-unstable](https://github.com/NixOS/nixpkgs/tree/nixos-unstable) and [Hyprland](https://hyprland.org/).
Most of the config here is for my Framework 13 with an AMD Ryzen 5 7640U, so some things may need to be changed in your case!

![Overview Screenshot](assets/overviewscrnsht.png)

## Installation

1. Make and boot an [unstable](https://channels.nixos.org/nixos-unstable) (or stable, but preferably unstable) NixOS Minimal installer USB

2. Connect to internet ([WiFi](https://nixos.org/manual/nixos/stable/#sec-installation-manual-networking) or Ethernet)

3. Install Git (we'll use nix-env as this is just an installer) `nix-env -iA nixos.gitMinimal`

4. Get this flake onto installer (use git or copy from USB drive) and then use `cd` to enter into that directory

5. Examine the configuration file for your machine, and add in proper device path for the drive you would like to install to, along with setting what size you want the swapfile in the disko configuration file (if you want a swap size other than 20GB, which should be optimal for 16GB of RAM with hibernation).

6. **!!THIS WILL ERASE YOUR DRIVE!!** Run the following command to partition disk using the disko configuration: `sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko disko/carbon-disko.nix`

7. Proceed to install NixOS with `sudo nixos-install --flake .#carbon`

8. After completion of install, reboot into the SSD you installed to. 

9. Log in using username and initialPassword set in configuration through GDM.

10. Change password with `passwd`

11. You should be good! All done!!

## Disk Encryption and Secure Boot

### Secure boot
TODO

### Disk Encryption

The disko config provided by `carbon-disko.nix` includes full disk encryption that will prompt you for an encryption password when you format the drive, and using it like that will work totally fine! The fun thing is, `carbon` is also configured for automatic decryption of the drive thanks to TPM2 and `systemd-cryptenroll`. To enable automatic decryption of your drive at boot using the TPM2 chip in your device, simply run `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+1+4+5+7 /dev/nvme0n1p2  ` if you have secure boot, or run `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+1+4+5 /dev/nvme0n1p2` if you do not! It will prompt you for your drive password, and then will automatically decrypt at boot!
