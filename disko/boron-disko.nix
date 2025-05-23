{
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
                  # 4GB should be good for 16GB of RAM w/o hibernation
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
