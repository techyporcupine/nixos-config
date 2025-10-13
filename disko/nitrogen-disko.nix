{
  # Disk layout for 'nitrogen' via disko
  # GPT partitioning with btrfs subvolumes (root, home, nix, swap) and vfat ESP.
  disko.devices = {
    disk = {
      # Set up disk called "vdb"
      vdb = {
        device = "/dev/sda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f"]; # Override existing partition
                # BTRFS Subvolumes and where they are mounted
                subvolumes = {
                  # The rootfs, mounted at / on the disk
                  "/rootfs" = {
                    mountpoint = "/";
                  };
                  # the home dir, mounted at /home on the disk with some nice zstd compression
                  "/home" = {
                    mountOptions = ["compress=zstd"];
                    mountpoint = "/home";
                  };
                  # the nix dir, mounted at /nix on the disk, also with some nice zstd compression
                  "/nix" = {
                    mountOptions = ["compress=zstd" "noatime"];
                    mountpoint = "/nix";
                  };
                  # Subvolume for the swapfile, mounted at /.swapvol
                  # 4GB swap recommended for ~16GB RAM if not hibernating
                  "/swap" = {
                    mountpoint = "/.swapvol";
                    swap = {
                      swapfile.size = "4G";
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
