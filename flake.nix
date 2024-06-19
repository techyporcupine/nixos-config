{
  description = "techyporcupine's NixOS Config!";

  inputs = {
    hyprland = {
      url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    };
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs-staging.url = "github:nixos/nixpkgs/staging-next";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Nixos-hardware
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    
    # Packages I just want the latest of
    waybar.url = "github:Alexays/Waybar/master";
    hypridle.url = "github:hyprwm/hypridle/main";

    # Home manager config
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, nixos-hardware, home-manager, hyprland, nixpkgs-staging, disko, waybar, hypridle, ... }@inputs:
    let
      inherit (self) outputs;
      overlay-stable = final: prev: {
        stable = import nixpkgs-stable {
          system = final.system;
          config.allowUnfree = true;
        };
      };
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    # NixOS configuration entrypoint
    # To switch to new NixOS config 'sudo nixos-rebuild switch --flake .#frankentop'
    in {
      nixosConfigurations = {
        frankentop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {inherit inputs outputs;};
          # Path to NixOS configuration
          modules = [ 
            ({ config, pkgs, ... }: { nixpkgs.overlays = [ 
              overlay-stable
            ]; })
            disko.nixosModules.disko
            ./machines/frankentop.nix 
            ./disko/frankendisko.nix
            ./nixos
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.techyporcupine = import ./home-manager/home.nix;
              home-manager.extraSpecialArgs = {inherit inputs outputs;};
            }
          ];
        };
      };

      # Standalone home-manager configuration entrypoint
      # To switch to new home-manager setup 'home-manager switch --flake .#techyporcupine'
      #homeConfigurations = {
      #  "techyporcupine" = home-manager.lib.homeManagerConfiguration {
      #    pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
      #    extraSpecialArgs = {inherit inputs outputs;};
      #    # Path to home-manager configuration
      #    modules = [ 
      #      ({ config, pkgs, ... }: { nixpkgs.overlays = [ overlay-stable ]; })
      #      hyprland.homeManagerModules.default
      #      ./home-manager/home.nix
      #    ];
      #  };
      #};
    };
}
