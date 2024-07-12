# Home manager config file

{ inputs, lib, config, pkgs, ... }: {
  # You can import other home-manager modules here
  imports = [
    ./programs
  ];

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
}
