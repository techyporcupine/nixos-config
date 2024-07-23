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

    # Nix-minecraft for mc server
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";

    # Catppuccin
    catppuccin.url = "github:techyporcupine/ctp-nix";

    # Disko
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Nixos-hardware
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    
    # Sops-nix for secrets
    sops-nix.url = "github:Mic92/sops-nix";

    # Packages I just want the latest of
    waybar.url = "github:Alexays/Waybar/master";
    hypridle.url = "github:hyprwm/hypridle/main";
    ladybird.url = "github:LadybirdBrowser/ladybird";

    # Home manager config
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, ... }@inputs:
    let
      inherit (self) outputs;
      overlay-stable = final: prev: {
        stable = import inputs.nixpkgs-stable {
          system = final.system;
          config.allowUnfree = true;
        };
      };
      overlay-tp = final: prev: {
        tp = import inputs.nixpkgs-tp {
          system = final.system;
          config.allowUnfree = true;
        };
      };
      overlay-cuda = final: prev: {
        # change from nixpkgs to nixpkgs-cuda if needed, also change the hash at nixpkgs-cuda
        pkgsCuda = import inputs.nixpkgs {
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
      forAllSystems = inputs.nixpkgs.lib.genAttrs systems;
    # NixOS configuration entrypoint
    # To switch to new NixOS config 'sudo nixos-rebuild switch --flake .#frankentop'
    in {
      nixosConfigurations = {
        frankentop = inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {inherit inputs outputs;};
          # Path to NixOS configuration
          modules = [ 
            ({ config, pkgs, ... }: { nixpkgs.overlays = [ 
              overlay-stable
              overlay-tp
              overlay-cuda
            ]; })
            inputs.disko.nixosModules.disko
            inputs.sops-nix.nixosModules.sops
            ./machines/frankentop.nix 
            ./disko/frankentop-disko.nix
            ./nixos
            inputs.home-manager.nixosModules.home-manager
            inputs.catppuccin.nixosModules.catppuccin
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {inherit inputs outputs;};
              # FIXME: Change username here if you changed the HM username
              home-manager.users.techyporcupine.imports = [ inputs.catppuccin.homeManagerModules.catppuccin ];
            }
          ];
        };
        lithium = inputs.nixpkgs-stable.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = {inherit inputs outputs;};
          # Path to NixOS configuration
          modules = [ 
            ({ config, pkgs, ... }: { nixpkgs.overlays = [ 
              overlay-stable
              overlay-tp
              overlay-cuda
            ]; })
            {
              nixpkgs.config.pkgs = import inputs.nixpkgs-stable { inherit systems; };
            }
            inputs.disko.nixosModules.disko
            inputs.sops-nix.nixosModules.sops
            ./machines/lithium.nix 
            ./disko/lithium-disko.nix
            ./nixos
            inputs.home-manager.nixosModules.home-manager
            inputs.catppuccin.nixosModules.catppuccin
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {inherit inputs outputs;};
              # FIXME: Change username here if you changed the HM username
              home-manager.users.lithium.imports = [ inputs.catppuccin.homeManagerModules.catppuccin ];
            }
          ];
        };
      };

      # Standalone home-manager configuration entrypoint (VERY OLD)
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
