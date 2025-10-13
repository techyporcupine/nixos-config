{
  description = "techyporcupine's NixOS Config!";

  # Dependencies: package sources, modules, and overlays
  inputs = {
    # Main package repository (unstable channel)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Additional package channels for stable/testing packages
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-staging.url = "github:nixos/nixpkgs/staging-next";
    nixpkgs-tp.url = "github:techyporcupine/nixpkgs/patch-1";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";

    #companion-satellite = {
    #  url = "path:nixos/pkgs/companion-satellite";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};

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
    catppuccin = {
      url = "github:catppuccin/nix";
    };

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
      url = "github:ggml-org/llama.cpp/b6700";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secure boot support
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Chaotic-AUR packages
    nyx = {
      url = "github:chaotic-cx/nyx";
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
  outputs = {self, ...} @ inputs: let
    inherit (self) outputs;
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
    # Supported architectures
    systems = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    forAllSystems = inputs.nixpkgs.lib.genAttrs systems;
  in {
    # Machine configurations - switch with `nh os switch ./`
    nixosConfigurations = {
      # Framework laptop
      carbon = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [
          # Apply package overlays
          ({
            config,
            pkgs,
            ...
          }: {
            nixpkgs.overlays = [
              overlay-stable
              overlay-tp
              overlay-staging
              overlay-master
              inputs.llama-cpp.overlays.default
              (import ./nixos/pkgs/llama-cpp.nix {inherit inputs;})
            ];
          })
          # Core system modules
          inputs.disko.nixosModules.disko
          ./machines/carbon.nix
          ./disko/carbon-disko.nix
          ./nixos
          inputs.home-manager.nixosModules.home-manager
          inputs.catppuccin.nixosModules.catppuccin
          inputs.nixos-hardware.nixosModules.framework-13-7040-amd
          inputs.lanzaboote.nixosModules.lanzaboote
          inputs.nyx.nixosModules.default
          # Home Manager configuration
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {inherit inputs outputs;};
            # FIXME: Change username here if you changed the HM username
            home-manager.users.techyporcupine.imports = [inputs.catppuccin.homeModules.catppuccin];
          }
        ];
      };
      # Framework laptop (backup/secondary)
      beryllium = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [
          # Apply package overlays
          ({
            config,
            pkgs,
            ...
          }: {
            nixpkgs.overlays = [
              overlay-stable
              overlay-tp
              overlay-staging
              overlay-master
              inputs.llama-cpp.overlays.default
              (import ./nixos/pkgs/llama-cpp.nix {inherit inputs;})
            ];
          })
          # Core system modules
          inputs.disko.nixosModules.disko
          ./machines/beryllium.nix
          ./disko/beryllium-disko.nix
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
            # home-manager.users.beryllium.imports = [inputs.catppuccin.homeModules.catppuccin];
          }
        ];
      };
      # Server
      helium = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [
          # Apply package overlays
          ({
            config,
            pkgs,
            ...
          }: {
            nixpkgs.overlays = [
              overlay-stable
              overlay-tp
              overlay-staging
              overlay-master
            ];
          })
          # Core system modules
          inputs.disko.nixosModules.disko
          ./machines/helium.nix
          ./disko/helium-disko.nix
          ./nixos
          inputs.home-manager.nixosModules.home-manager
          inputs.catppuccin.nixosModules.catppuccin
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {inherit inputs outputs;};
            # FIXME: Change username here if you changed the HM username
            # home-manager.users.helium.imports = [inputs.catppuccin.homeModules.catppuccin];
          }
        ];
      };
      # Desktop workstation
      boron = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [
          # Apply package overlays
          ({
            config,
            pkgs,
            ...
          }: {
            nixpkgs.overlays = [
              overlay-stable
              overlay-tp
              overlay-staging
              overlay-master
              inputs.llama-cpp.overlays.default
              (import ./nixos/pkgs/llama-cpp.nix {inherit inputs;})
            ];
          })
          # Core system modules
          inputs.disko.nixosModules.disko
          ./machines/boron.nix
          ./disko/boron-disko.nix
          ./nixos
          inputs.home-manager.nixosModules.home-manager
          inputs.catppuccin.nixosModules.catppuccin
          inputs.lanzaboote.nixosModules.lanzaboote
          inputs.nyx.nixosModules.default
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {inherit inputs outputs;};
            # FIXME: Change username here if you changed the HM username
            # home-manager.users.boron.imports = [inputs.catppuccin.homeModules.catppuccin];
          }
        ];
      };
      # Server with LLM support
      nitrogen = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [
          # Apply package overlays
          ({
            config,
            pkgs,
            ...
          }: {
            nixpkgs.overlays = [
              overlay-stable
              overlay-tp
              overlay-staging
              overlay-master
              inputs.llama-cpp.overlays.default
              (import ./nixos/pkgs/llama-cpp.nix {inherit inputs;})
            ];
          })
          # Core system modules
          inputs.disko.nixosModules.disko
          ./machines/nitrogen.nix
          ./disko/nitrogen-disko.nix
          ./nixos
          inputs.home-manager.nixosModules.home-manager
          inputs.catppuccin.nixosModules.catppuccin
          inputs.lanzaboote.nixosModules.lanzaboote
          inputs.nyx.nixosModules.default
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {inherit inputs outputs;};
            # FIXME: Change username here if you changed the HM username
            # home-manager.users.nitrogen.imports = [inputs.catppuccin.homeModules.catppuccin];
          }
        ];
      };
      # Additional server
      lithium = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [
          # Apply package overlays
          ({
            config,
            pkgs,
            ...
          }: {
            nixpkgs.overlays = [
              overlay-stable
              overlay-tp
              overlay-staging
              overlay-master
            ];
          })
          # Core system modules
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
            # home-manager.users.lithium.imports = [inputs.catppuccin.homeModules.catppuccin];
          }
        ];
      };
    };
  };
}
