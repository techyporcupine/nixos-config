{
  # Disk layout for 'carbon' via disko
  # Uses LUKS (cryptroot) for full-disk encryption, then btrfs inside LUKS.
  # NOTE: `allowDiscards = true` enables TRIM inside the LUKS device.
  disko.devices = {
    disk = {
      # Set up disk called "vdb"
      vdb = {
        device = "/dev/nvme0n1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                settings = {
                  allowDiscards = true;
                };
                content = {
                  type = "btrfs";
                  extraArgs = ["-L" "nixos" "-f"]; # label and force
                  subvolumes = {
                    "/rootfs" = {
                      mountpoint = "/";
                    };
                    "/home" = {
                      mountpoint = "/home";
                      mountOptions = ["compress=zstd"];
                    };
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = ["compress=zstd" "noatime"];
                    };
                    "/swap" = {
                      mountpoint = "/swap";
                      swap.swapfile.size = "20G";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
