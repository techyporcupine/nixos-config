{
  description = "techyporcupine's NixOS Config!";

  # Dependencies: package sources, modules, and overlays
  inputs = {
    # Main package repository (unstable channel)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Additional package channels for stable/testing packages
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-staging.url = "github:nixos/nixpkgs/staging-next";
    nixpkgs-tp.url = "github:techyporcupine/nixpkgs/patch-1";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";

    # Wayland compositor with eye candy effects
    swayfx = {
      url = "git+https://github.com/WillPower3309/swayfx";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Minecraft server management
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Catppuccin theme
    catppuccin.url = "github:catppuccin/nix";

    # Declarative disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware-specific configurations
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };

    # Local LLM inference engine
    llama-cpp = {
      url = "github:ggml-org/llama.cpp/b7422";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secure boot support
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Latest versions of specific packages
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

    # User environment management
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-stable = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
  };

  # System configurations and build outputs
  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    inherit (self) outputs;
    inherit (nixpkgs) lib;

    # Overlay to access stable packages alongside unstable
    overlay-stable = final: prev: {
      stable = import inputs.nixpkgs-stable {
        system = final.system;
        config.allowUnfree = true;
      };
    };
    # Custom fork overlay
    overlay-tp = final: prev: {
      tp = import inputs.nixpkgs-tp {
        system = final.system;
        config.allowUnfree = true;
      };
    };
    # Staging packages overlay
    overlay-staging = final: prev: {
      staging = import inputs.nixpkgs-staging {
        system = final.system;
        config.allowUnfree = true;
      };
    };
    # Master branch overlay
    overlay-master = final: prev: {
      master = import inputs.nixpkgs-master {
        system = final.system;
        config.allowUnfree = true;
      };
    };

    # Common overlays for all systems
    baseOverlays = [
      overlay-stable
      overlay-tp
      overlay-staging
      overlay-master
    ];

    # Overlays with llama-cpp support
    llamaOverlays =
      baseOverlays
      ++ [
        inputs.llama-cpp.overlays.default
        (import ./nixos/pkgs/llama-cpp.nix {inherit inputs lib;})
      ];

    # Common modules for all systems
    commonModules = [
      inputs.disko.nixosModules.disko
      ./nixos
      inputs.home-manager.nixosModules.home-manager
      inputs.catppuccin.nixosModules.catppuccin
    ];

    # Helper function to create system configurations
    mkSystem = {
      hostname,
      overlays ? baseOverlays,
      extraModules ? [],
      homeManagerUser ? null,
    }:
      inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        modules =
          [
            # Apply package overlays
            ({
              config,
              pkgs,
              ...
            }: {
              nixpkgs.overlays = overlays;
            })
            # Machine-specific configuration
            ./machines/${hostname}.nix
            ./disko/${hostname}-disko.nix
          ]
          ++ commonModules
          ++ extraModules
          ++ (
            if homeManagerUser != null
            then [
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = {inherit inputs outputs;};
                home-manager.users.${homeManagerUser}.imports = [
                  inputs.catppuccin.homeModules.catppuccin
                ];
              }
            ]
            else [
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = {inherit inputs outputs;};
              }
            ]
          );
      };
  in {
    # Machine configurations - switch with `nh os switch ./`
    nixosConfigurations = {
      # Framework laptop
      carbon = mkSystem {
        hostname = "carbon";
        overlays = llamaOverlays;
        homeManagerUser = "techyporcupine";
        extraModules = [
          inputs.nixos-hardware.nixosModules.framework-13-7040-amd
          inputs.lanzaboote.nixosModules.lanzaboote
        ];
      };

      # Framework laptop (backup/secondary)
      beryllium = mkSystem {
        hostname = "beryllium";
        overlays = llamaOverlays;
        extraModules = [
          inputs.nixos-hardware.nixosModules.framework-13-7040-amd
          inputs.lanzaboote.nixosModules.lanzaboote
        ];
      };

      # Server
      helium = mkSystem {
        hostname = "helium";
      };

      # Desktop workstation
      boron = mkSystem {
        hostname = "boron";
        overlays = llamaOverlays;
        extraModules = [
          inputs.lanzaboote.nixosModules.lanzaboote
        ];
      };

      # Server with LLM support
      nitrogen = mkSystem {
        hostname = "nitrogen";
        overlays = llamaOverlays;
        extraModules = [
          inputs.lanzaboote.nixosModules.lanzaboote
        ];
      };

      # Additional server
      lithium = mkSystem {
        hostname = "lithium";
      };
    };
  };
}
