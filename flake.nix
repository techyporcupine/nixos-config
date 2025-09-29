{
  description = "techyporcupine's NixOS Config!";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-staging.url = "github:nixos/nixpkgs/staging-next";
    nixpkgs-tp.url = "github:techyporcupine/nixpkgs/patch-1";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";

    #companion-satellite = {
    #  url = "path:nixos/pkgs/companion-satellite";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};

    akvorado = {
      url = "github:akvorado/akvorado";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Quickemu
    quickemu = {
      url = "github:quickemu-project/quickemu";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
      url = "github:catppuccin/nix";
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

    llama-cpp = {
      url = "github:ggml-org/llama.cpp/3913f8730ec6d6245480affc30ae3049107956f4";
      inputs.nixpkgs.follows = "nixpkgs";
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

    # Home manager config
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-stable = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs-stable";
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
    overlay-master = final: prev: {
      master = import inputs.nixpkgs-master {
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
              overlay-master
              inputs.llama-cpp.overlays.default
              (import ./nixos/pkgs/llama-cpp.nix {inherit inputs;})
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
            home-manager.users.techyporcupine.imports = [inputs.catppuccin.homeModules.catppuccin];
          }
        ];
      };
      beryllium = inputs.nixpkgs.lib.nixosSystem {
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
              overlay-master
              inputs.llama-cpp.overlays.default
              (import ./nixos/pkgs/llama-cpp.nix {inherit inputs;})
            ];
          })
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
      helium = inputs.nixpkgs.lib.nixosSystem {
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
              overlay-master
            ];
          })
          #{
          #  nixpkgs.config.pkgs = import inputs.nixpkgs {inherit systems;};
          #}
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
      boron = inputs.nixpkgs.lib.nixosSystem {
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
              overlay-master
              inputs.llama-cpp.overlays.default
              (import ./nixos/pkgs/llama-cpp.nix {inherit inputs;})
            ];
          })
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
      nitrogen = inputs.nixpkgs.lib.nixosSystem {
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
              overlay-master
              inputs.llama-cpp.overlays.default
              (import ./nixos/pkgs/llama-cpp.nix {inherit inputs;})
            ];
          })
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
      lithium = inputs.nixpkgs.lib.nixosSystem {
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
              overlay-master
            ];
          })
          #{
          #  nixpkgs.config.pkgs = import inputs.nixpkgs {inherit systems;};
          #}
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
