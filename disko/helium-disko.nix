{
  disko.devices = {
    disk = {
      # Set up disk called "vdb"
      vdb = {
        device = "/dev/mmcblk0";
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
                };
              };
            };
          };
        };
      };
    };
  };
}
