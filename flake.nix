{
  description = "techyporcupine's NixOS Config!";

  inputs = {
    # Hyprland (weird config cus they said to)
    hyprland = {
      url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    };

    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-staging.url = "github:nixos/nixpkgs/staging-next";
    nixpkgs-tp.url = "github:techyporcupine/nixpkgs";

    # Nix-minecraft
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";

    # Disko
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Nixos-hardware
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    
    # Packages I just want the latest of
    waybar.url = "github:Alexays/Waybar/master";
    hypridle.url = "github:hyprwm/hypridle/main";
    ladybird.url = "github:LadybirdBrowser/ladybird";

    # Home manager config
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, nixpkgs-tp, nixos-hardware, home-manager, hyprland, nixpkgs-staging, disko, waybar, hypridle, ladybird, nix-minecraft, ... }@inputs:
    let
      inherit (self) outputs;
      overlay-stable = final: prev: {
        stable = import nixpkgs-stable {
          system = final.system;
          config.allowUnfree = true;
        };
      };
      overlay-tp = final: prev: {
        tp = import nixpkgs-tp {
          system = final.system;
          config.allowUnfree = true;
        };
      };
      overlay-cuda = final: prev: {
        # change from nixpkgs to nixpkgs-cuda if needed, also change the hash at nixpkgs-cuda
        pkgsCuda = import nixpkgs {
          system = final.system;
          config.cudaSupport = true; 
          # config.cudaCapabilities = [ "5.0" ]; 
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
              overlay-tp
              overlay-cuda
            ]; })
            disko.nixosModules.disko
            ./machines/frankentop.nix 
            ./disko/frankentop-disko.nix
            ./nixos
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
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
