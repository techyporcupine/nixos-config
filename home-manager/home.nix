# Home manager config file

{ inputs, lib, config, pkgs, ... }: {
  # You can import other home-manager modules here
  imports = [
    ./programs
  ];

  # HM Nixpkgs config 
  nixpkgs = {
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = (_: true);
      permittedInsecurePackages = [
        "electron-19.1.9"
        "electron-25.9.0"
      ];
    };
  };

  # Define user
  home = {
    username = "techyporcupine";
    homeDirectory = "/home/techyporcupine";
  };

  # Packages just for techyporcupine
  home.packages = with pkgs; [ 
    webcord
    cava
    scrcpy
    yubikey-manager-qt
    yubikey-personalization-gui
    lshw
    usbutils
    libreoffice-fresh
    audacity
    pavucontrol
    ffmpeg_6
    python3
    android-tools
    rpi-imager
    chromium
    calibre
    gthumb
    annotator
    super-slicer-beta
  ];

  # Enable home-manager and git
  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    userName  = "techyporcupine";
    userEmail = "git@cb-tech.me";
    signing = {
      signByDefault = true;
      key = "~/.ssh/id_ed25519";
    };
    extraConfig = {
      gpg = {
        format = "ssh";
      };
    };
  };

  # Enable SSH agest
  services = {
    ssh-agent.enable = true;
  };

  programs = {
    # SSH home config
    ssh = {
      enable = true;
      addKeysToAgent = "yes";
      # Config for clients you can ssh to without all their info.
      matchBlocks = {
        "helium" = {
          forwardAgent = true;
          hostname = "10.0.0.133";
          setEnv = { TERM = "kitty"; };
        };
        "nixserve" = {
          forwardAgent = true;
          hostname = "10.0.0.5";
          setEnv = { TERM = "kitty"; };
        };
        "printers" = {
          forwardAgent = true;
          user = "printers";
          hostname = "10.0.0.30";
          setEnv = { TERM = "kitty"; };
        };
        "switch" = {
          hostname = "10.0.0.4";
          user = "admin";
          extraOptions = {
            PubkeyAcceptedAlgorithms = "+ssh-rsa";
            HostkeyAlgorithms = "+ssh-rsa";
            Ciphers = "aes128-ctr";
            KexAlgorithms = "+diffie-hellman-group1-sha1";
          };
        };
      };
    };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}
