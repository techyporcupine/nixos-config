# Miscellaneous system configuration module
# Configures locale, timezone, hardware, SSH, shell, and sound
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
    # Time zone configuration with automatic detection
    time = {
      timeZone = lib.mkDefault "America/New_York";
    };
    # Automatically update timezone based on location
    services.automatic-timezoned.enable = true;

    # Locale configuration
    i18n = {
      defaultLocale = "en_US.UTF-8";
    };

    # Hardware support configuration
    hardware = {
      # Enable I2C for monitor configuration (ddcutil)
      i2c.enable = true;
      # Enable Bluetooth support
      bluetooth.enable = true;
      # Enable experimental Bluetooth features
      bluetooth.settings.General.Experimental = "true";
    };

    # Enable hardware graphics acceleration
    hardware.graphics = {
      enable = true;
      #extraPackages = with pkgs; [
      #  rocmPackages.clr.icd
      #];
    };

    # Enable Home Manager for user configuration
    tp.hm.programs.home-manager.enable = true;
    # Reload systemd user services on switch
    tp.hm.systemd.user.startServices = "sd-switch";

    # Enable firmware update daemon
    services.fwupd.enable = true;

    # Enable power management daemon
    services.upower.enable = true;

    # SSH server configuration
    services.openssh = {
      enable = true;
      # Allow password authentication
      settings.PasswordAuthentication = true;
      # Disable keyboard-interactive authentication
      settings.KbdInteractiveAuthentication = false;
    };
    # Enable SSH agent for key management
    programs.ssh.startAgent = true;
    tp.hm.services = {
      ssh-agent.enable = true;
    };
    # Disable GNOME's SSH agent (conflicts with ssh-agent)
    services.gnome.gcr-ssh-agent.enable = lib.mkForce false;
    tp.hm.programs = {
      ssh = {
        enable = true;

        # SSH client configuration for known hosts
        matchBlocks = {
          # Default settings for all hosts
          "*" = {
            # Automatically add keys to SSH agent
            addKeysToAgent = "yes";
            # Set terminal type for remote sessions
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
      # Zsh shell configuration
      zsh = {
        enable = true;
        # Enable Oh My Zsh framework
        oh-my-zsh = {
          enable = true;
          plugins = [
            "git" # Git aliases and completion
            "sudo" # Press ESC twice to add sudo to command
          ];
        };
        # Shell command aliases
        shellAliases = {
          c = "clear";
          tsu = "sudo tailscale up --accept-routes";
          tsd = "sudo tailscale down";
        };
        # Enable command suggestions based on history
        autosuggestion.enable = true;
        # Enable shell completion
        enableCompletion = true;
        # Enable syntax highlighting
        syntaxHighlighting.enable = true;
      };
      # Starship prompt theme configuration
      starship = {
        enable = true;
        enableZshIntegration = true;
        # Custom prompt format and styling
        settings = {
          # Left side: hostname, directory, prompt character, git info
          format = "$hostname$directory$character$git_branch$git_status";
          # Right side: exit status and command duration
          right_format = "$status$cmd_duration";
          # Prompt character styling
          character = {
            success_symbol = "[❯](blue)";
            error_symbol = "[❯](red)";
          };
          # Command exit status indicators
          status = {
            disabled = false;
            format = "[$symbol]($style)";
            symbol = "[✘ ](red)";
            success_symbol = "[✔ ](green)";
          };
          # Git branch display
          git_branch = {
            format = "[$branch]($style) ";
            style = "bold green";
          };
          # Directory display (truncated)
          directory = {
            style = "blue";
            truncation_length = 1;
            truncation_symbol = "";
            fish_style_pwd_dir_length = 1;
          };
          # Always show command duration
          cmd_duration = {
            min_time = 0;
          };
          # Always show hostname
          hostname = {
            ssh_only = false;
          };
        };
      };
    };

    # Sound configuration using PipeWire
    # Disable PulseAudio
    services.pulseaudio.enable = false;
    # Enable RealtimeKit for low-latency audio
    security.rtkit.enable = true;
    # Enable PipeWire sound server
    services.pipewire = {
      enable = true;
      # Enable ALSA support
      alsa.enable = true;
      # Enable 32-bit ALSA support for games
      alsa.support32Bit = true;
      # Enable PulseAudio compatibility
      pulse.enable = true;
      #jack.enable = true;
    };

    # System-wide utility packages
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
