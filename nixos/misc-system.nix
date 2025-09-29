{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.tp.system;
in {
  options.tp.system = {
    enable = lib.mkEnableOption "TP's system config (locale, timezone, kb layout, i2c, bluetooth)";
  };

  config = lib.mkIf cfg.enable {
    # TIME CONFIG
    time = {
      timeZone = lib.mkDefault "America/New_York";
    };
    services.automatic-timezoned.enable = true;

    # LOCALE CONFIG
    i18n = {
      defaultLocale = "en_US.UTF-8";
    };

    # HARDWARE CONFIG
    hardware = {
      # Enable I2C (monitor config using ddcutil)
      i2c.enable = true;
      # Enable Bluetooth
      bluetooth.enable = true;
      bluetooth.settings.General.Experimental = "true";
    };

    hardware.graphics = {
      enable = true;
      #extraPackages = with pkgs; [
      #  rocmPackages.clr.icd
      #];
    };

    # Enable HomeManager
    tp.hm.programs.home-manager.enable = true;
    tp.hm.systemd.user.startServices = "sd-switch";

    # Enable FWUPD for firmware updating
    services.fwupd.enable = true;

    # Enable UPower for Dbus power management
    services.upower.enable = true;

    # SSH Config
    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = true;
      settings.KbdInteractiveAuthentication = false;
    };
    programs.ssh.startAgent = true;
    tp.hm.services = {
      ssh-agent.enable = true;
    };
    services.gnome.gcr-ssh-agent.enable = lib.mkForce false;
    tp.hm.programs = {
      ssh = {
        enable = true;

        # Config for clients you can ssh to without all their info.
        matchBlocks = {
          "*" = {
            addKeysToAgent = "yes";
            setEnv = {TERM = "kitty";};
          };
          "printers" = {
            forwardAgent = true;
            user = "printers";
            hostname = "printers";
          };
          "beryllium" = {
            forwardAgent = true;
            user = "beryllium";
            hostname = "10.0.0.5";
          };
          "helium" = {
            forwardAgent = true;
            user = "helium";
            hostname = "2001:470:e251:1000::6";
          };
          "heliumv4" = {
            forwardAgent = true;
            user = "helium";
            hostname = "172.16.0.6";
          };
          "boron" = {
            forwardAgent = true;
            user = "boron";
            hostname = "10.0.0.10";
          };
          "nitrogen" = {
            forwardAgent = true;
            user = "nitrogen";
            hostname = "10.0.0.11";
          };
          "lithium" = {
            forwardAgent = true;
            user = "lithium";
            hostname = "10.0.0.14";
          };
          "3750xmgmt" = {
            hostname = "172.16.0.1";
            user = "admin";
            extraOptions = {
              PubkeyAcceptedAlgorithms = "+ssh-rsa";
              HostkeyAlgorithms = "+ssh-rsa";
              Ciphers = "aes128-ctr";
              KexAlgorithms = "+diffie-hellman-group1-sha1";
            };
          };
          "3750x" = {
            hostname = "10.0.0.9";
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

    tp.hm.programs = {
      # Zsh configuration
      zsh = {
        enable = true;
        oh-my-zsh = {
          enable = true;
          plugins = [
            "git"
            "sudo"
          ];
        };
        # Defined aliases to be used inside of the shell
        shellAliases = {
          c = "clear";
          tsu = "sudo tailscale up --accept-routes";
          tsd = "sudo tailscale down";
        };
        autosuggestion.enable = true;
        enableCompletion = true;
        syntaxHighlighting.enable = true;
      };
      # Configuration for starship, my zsh theme
      starship = {
        enable = true;
        enableZshIntegration = true;
        settings = {
          format = "$hostname$directory$character$git_branch$git_status";
          right_format = "$status$cmd_duration";
          character = {
            success_symbol = "[❯](blue)";
            error_symbol = "[❯](red)";
          };
          status = {
            disabled = false;
            format = "[$symbol]($style)";
            symbol = "[✘ ](red)";
            success_symbol = "[✔ ](green)";
          };
          git_branch = {
            format = "[$branch]($style) ";
            style = "bold green";
          };
          directory = {
            style = "blue";
            truncation_length = 1;
            truncation_symbol = "";
            fish_style_pwd_dir_length = 1;
          };
          cmd_duration = {
            min_time = 0;
          };
          hostname = {
            ssh_only = false;
          };
        };
      };
    };

    # SOUND CONFIG
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      #jack.enable = true;
    };

    environment.systemPackages = with pkgs; [
      home-manager
      wget
      fastfetch
      pciutils
      unzip
      htop
      xorg.xhost
      sshfs
      nmap
      btop
      ffmpeg_6
      python3
      android-tools
      lshw
      usbutils
      cava
      tmux
      ripgrep
      neovim
      fd
    ];
  };
}
