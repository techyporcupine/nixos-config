{
  description = "techyporcupine's NixOS Config!";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-staging.url = "github:nixos/nixpkgs/staging-next";
    nixpkgs-tp.url = "github:techyporcupine/nixpkgs";

    # SwayFX
    swayfx = {
      url = "git+https://github.com/WillPower3309/swayfx";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix-minecraft for mc server
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Catppuccin
    catppuccin = {
      url = "github:techyporcupine/ctp-nix";
    };

    # Disko
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nixos-hardware
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };

    # Add Lanzaboote for secure boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nyx
    nyx = {
      url = "github:chaotic-cx/nyx";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Packages I just want the latest of
    waybar = {
      url = "github:Alexays/Waybar/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hypridle = {
      url = "github:hyprwm/hypridle/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprpaper = {
      url = "github:hyprwm/hyprpaper/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ladybird = {
      url = "github:LadybirdBrowser/ladybird";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home manager config
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {self, ...} @ inputs: let
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
    overlay-staging = final: prev: {
      staging = import inputs.nixpkgs-staging {
        system = final.system;
        config.allowUnfree = true;
      };
    };
    systems = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    forAllSystems = inputs.nixpkgs.lib.genAttrs systems;
    # NixOS configuration entrypoint
    # To switch to new NixOS config 'nh os switch ./' as long as the hostname of your device is the same as the nixosConfiguration name!
  in {
    nixosConfigurations = {
      carbon = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        # Path to NixOS configuration
        modules = [
          ({
            config,
            pkgs,
            ...
          }: {
            nixpkgs.overlays = [
              overlay-stable
              overlay-tp
              overlay-staging
            ];
          })
          inputs.disko.nixosModules.disko
          ./machines/carbon.nix
          ./disko/carbon-disko.nix
          ./nixos
          inputs.home-manager.nixosModules.home-manager
          inputs.catppuccin.nixosModules.catppuccin
          inputs.nixos-hardware.nixosModules.framework-13-7040-amd
          inputs.lanzaboote.nixosModules.lanzaboote
          inputs.nyx.nixosModules.default
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {inherit inputs outputs;};
            # FIXME: Change username here if you changed the HM username
            home-manager.users.techyporcupine.imports = [inputs.catppuccin.homeManagerModules.catppuccin];
          }
        ];
      };
      lithium = inputs.nixpkgs-stable.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {inherit inputs outputs;};
        # Path to NixOS configuration
        modules = [
          ({
            config,
            pkgs,
            ...
          }: {
            nixpkgs.overlays = [
              overlay-stable
              overlay-tp
              overlay-staging
            ];
          })
          {
            nixpkgs.config.pkgs = import inputs.nixpkgs-stable {inherit systems;};
          }
          inputs.disko.nixosModules.disko
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
            home-manager.users.lithium.imports = [inputs.catppuccin.homeManagerModules.catppuccin];
          }
        ];
      };
    };
  };
}
