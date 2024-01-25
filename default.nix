{ config, lib, disko, ... }:
with lib;
let
  # Shorter name to access final settings a 
  # user of hello.nix module HAS ACTUALLY SET.
  # cfg is a typical convention.
  cfg = config.hardware.diskconfig;
in
{
  imports = [ disko.nixosModules.disko ];

  options.hardware.diskconfig = {
    enable = mkEnableOption "hello service";
    isBootstrap = mkOption {
      type = types.bool;
      description = lib.mdDoc ''
        If is bootstrap is true, then the disko config is executed.
      '';
    };
    device = mkOption {
      type = types.str;
      default = "/dev/sda";
      description = lib.mdDoc ''
        Path to disk. When Disko generates disk images, it actually runs a QEMU
        virtual machine and runs the installation steps. Whether your VPS
        recognizes its hard disk as "sda" or "vda" doesn't matter. We abide to
        Disko's QEMU VM and use "vda" here.
      '';
    };
    swap = mkOption {
      type = types.int;
      default = 4;
      description = lib.mdDoc ''
        The size of swap partition in GB
      '';
    };
  };

  config = mkIf cfg.enable {


    disko = mkIf cfg.isBootstrap {
      # Do not let Disko manage fileSystems.* config for NixOS.
      # Reason is that Disko mounts partitions by GPT partition names, which are
      # easily overwritten with tools like fdisk. When you fail to deploy a new
      # config in this case, the old config that comes with the disk image will
      # not boot either.
      enableConfig = false;

      # Define a disk
      devices.disk.main = {
        type = "disk";
        device = cfg.device;

        content = {
          # Use GPT partition table. There seems to be some issues with MBR support
          # from Disko.
          type = "gpt";
          # Partition list
          partitions = {
            # Compared to MBR, GPT partition table doesn't reserve space for MBR
            # boot record. We need to reserve the first 1MB for MBR boot record,
            # so Grub can be installed here.
            boot = {
              name = "boot";
              size = "1M";
              type = "EF02"; # for grub MBR
              # Use the highest priority to ensure it's at the beginning
              priority = 0;
            };

            # ESP partition, or "boot" partition as you may call it. In theory,
            # this config will support VPSes with both EFI and BIOS boot modes.
            ESP = {
              name = "ESP";
              # Reserve 512MB of space per my own need. If you use more/less
              # on your boot partition, adjust accordingly.
              size = "512M";
              type = "EF00";
              # Use the second highest priority so it's before the remaining space
              priority = 1;
              # Format as FAT32
              content = {
                type = "filesystem";
                format = "vfat";
                # Use as boot partition. Disko use the information here to mount
                # partitions on disk image generation. Use the same settings as
                # fileSystems.*
                mountpoint = "/boot";
                mountOptions = [ "fmask=0077" "dmask=0077" ];
              };
            };

            # Parition to store the NixOS system, use all remaining space.
            root = {
              name = "root";
              size = "-${cfg.swap}G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [ "nosuid" "nodev" ];
              };
            };

            # Swap partition
            plainSwap = {
              name = "swap";
              size = "100%";
              content = {
                type = "swap";
                resumeDevice = true; # resume from hiberation from this device
              };
            };
          };
        };
      };
    };


    # /boot partition, second partition on the disk image. Since my VPS recognizes
    # hard drive as "sda", I specify "sda2" here. If your VPS recognizes the drive
    # differently, change accordingly
    fileSystems."/boot" = {
      device = lib.mkForce "${cfg.device}2";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

    # Since we aren't letting Disko manage fileSystems.*, we need to configure it ourselves
    # Root partition, third partition on the disk image. Since my VPS recognizes
    # hard drive as "sda", I specify "sda3" here. If your VPS recognizes the drive
    # differently, change accordingly
    fileSystems."/" = {
      device = lib.mkForce "${cfg.device}3";
      fsType = "ext4";
      options = [ "nosuid" "nodev" ];
    };

    swapDevices = [{ device = lib.mkForce "${cfg.device}4"; }];
  };
}
