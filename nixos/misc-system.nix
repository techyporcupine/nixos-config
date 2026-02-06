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
    # Time zone configuration
    time = {
      # Default to Eastern time, but can be overridden per-machine
      timeZone = lib.mkDefault "America/New_York";
    };
    # Automatically update timezone based on geolocation (useful for laptops)
    services.automatic-timezoned.enable = true;

    # Locale configuration (language, date format, currency, etc.)
    i18n = {
      defaultLocale = "en_US.UTF-8";
    };

    # Hardware support configuration
    hardware = {
      # Enable I2C bus access (needed for ddcutil to control monitor brightness/settings)
      i2c.enable = true;
      # Enable Bluetooth radio
      bluetooth.enable = true;
      # Enable experimental Bluetooth features (better LE Audio, codec support)
      bluetooth.settings.General.Experimental = "true";
    };

    # Enable hardware graphics acceleration (OpenGL, Vulkan, VA-API)
    hardware.graphics = {
      enable = true;
      #extraPackages = with pkgs; [
      #  rocmPackages.clr.icd  # Uncomment for AMD ROCm compute support
      #];
    };

    # Enable Home Manager for user-level configuration
    tp.hm.programs.home-manager.enable = true;
    # Restart changed systemd user services instead of warning (smoother updates)
    tp.hm.systemd.user.startServices = "sd-switch";

    # FWUPD: firmware update daemon (updates UEFI, peripherals via LVFS)
    services.fwupd.enable = true;

    # UPower: battery/power monitoring (shows battery status in UI)
    services.upower.enable = true;

    # SSH server configuration
    services.openssh = {
      enable = true;
      # Allow password authentication (in addition to key-based)
      settings.PasswordAuthentication = true;
      # Disable keyboard-interactive (prevents redundant password prompts)
      settings.KbdInteractiveAuthentication = false;
    };
    # Enable SSH agent system-wide (manages private keys in memory)
    programs.ssh.startAgent = true;
    tp.hm.services = {
      # Also enable SSH agent for user (home-manager integration)
      ssh-agent.enable = true;
    };
    # Force disable GNOME's SSH agent to prevent conflicts
    services.gnome.gcr-ssh-agent.enable = lib.mkForce false;

    tp.hm.programs = {
      ssh = {
        enable = true;

        # SSH client configuration for known hosts
        matchBlocks = {
          # Default settings for all hosts
          "*" = {
            # Auto-add keys to agent on first use (convenience)
            addKeysToAgent = "yes";
            # Set TERM to kitty for better remote terminal support
            setEnv = {TERM = "kitty";};
          };
          "printers" = {
            forwardAgent = true;
            user = "printers";
            hostname = "printers";
          };
          # Home lab servers (named after elements)
          "beryllium" = {
            forwardAgent = true;
            user = "beryllium";
            hostname = "10.0.0.5";
          };
          "helium" = {
            forwardAgent = true;
            user = "helium";
            hostname = "2001:470:e251:1000::6"; # IPv6 address
          };
          "heliumv4" = {
            forwardAgent = true;
            user = "helium";
            hostname = "172.16.0.6"; # IPv4 fallback
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
          # Cisco 3750X switch configs (legacy crypto for old hardware)
          "3750xmgmt" = {
            hostname = "172.16.0.1";
            user = "admin";
            extraOptions = {
              # Enable legacy algorithms (Cisco IOS only supports older SSH)
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
        # Oh My Zsh: community-driven framework with plugins/themes
        oh-my-zsh = {
          enable = true;
          plugins = [
            "git" # Git aliases and completion (gst, gco, etc.)
            "sudo" # Press ESC twice to prepend sudo to command
          ];
        };
        # Convenient shell aliases
        shellAliases = {
          c = "clear";
          tsu = "sudo tailscale up --accept-routes"; # Start Tailscale VPN
          tsd = "sudo tailscale down"; # Stop Tailscale VPN
        };
        # Show grayed-out suggestions from history as you type
        autosuggestion.enable = true;
        # Tab completion for commands and arguments
        enableCompletion = true;
        # Color-code valid/invalid commands as you type
        syntaxHighlighting.enable = true;
      };

      # Starship: fast, customizable prompt written in Rust
      starship = {
        enable = true;
        enableZshIntegration = true;
        settings = {
          # Left prompt: hostname, directory, prompt char, git info
          format = "$hostname$directory$character$git_branch$git_status";
          # Right prompt: status and timing
          right_format = "$status$cmd_duration";

          # Prompt character (❯)
          character = {
            success_symbol = "[❯](blue)"; # Blue when last command succeeded
            error_symbol = "[❯](red)"; # Red when last command failed
          };

          # Show checkmark/X for last command status
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

          # Show only last directory component (e.g., ~/foo/bar → bar)
          directory = {
            style = "blue";
            truncation_length = 1;
            truncation_symbol = "";
            fish_style_pwd_dir_length = 1; # Fish-style path shortening
          };

          # Always show how long commands take (helpful for slow ops)
          cmd_duration = {
            min_time = 0;
          };

          # Always show hostname (not just in SSH sessions)
          hostname = {
            ssh_only = false;
          };
        };
      };
    };

    # Sound configuration using PipeWire (modern replacement for PulseAudio/JACK)
    services.pulseaudio.enable = false; # PipeWire handles this
    # RealtimeKit: allows non-root processes to get realtime scheduling (low-latency audio)
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      # ALSA: Linux kernel sound API
      alsa.enable = true;
      # 32-bit ALSA for older games/applications
      alsa.support32Bit = true;
      # PulseAudio compatibility layer (most apps expect PulseAudio)
      pulse.enable = true;
      #jack.enable = true;  # Uncomment for pro audio (JACK) support
    };

    security.sudo = {
      enable = true;
      extraRules = [
        {
          groups = ["wheel"];
          commands = [
            {
              command = "/run/current-system/sw/bin/nixos-rebuild";
              options = ["NOPASSWD"];
            }
            {
              command = "/nix/store/*/bin/switch-to-configuration";
              options = ["NOPASSWD"];
            }
            {
              command = "/tmp/nh-os-*/result/bin/switch-to-configuration";
              options = ["NOPASSWD"];
            }
            {
              command = "/tmp/nh-os-*/result/bin/install-grub.sh";
              options = ["NOPASSWD"];
            }
            {
              command = "/nix/store/*/bin/install-grub.sh";
              options = ["NOPASSWD"];
            }
          ];
        }
      ];
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
