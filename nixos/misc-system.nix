{pkgs, config, lib, ... }: let cfg = config.tp.system; in {
  options.tp.system = {
    enable = lib.mkEnableOption "TP's system config (locale, timezone, kb layout, i2c, bluetooth)";
  };

  config = lib.mkIf cfg.enable {
    # TIME CONFIG
    time = {
      timeZone = "America/New_York";
    };

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
    tp.hm.programs = {
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
    
    # SOUND CONFIG
    hardware.pulseaudio.enable = false;
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
      neofetch
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
    ];
  };
}