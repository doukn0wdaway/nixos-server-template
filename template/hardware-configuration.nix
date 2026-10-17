# Placeholder that boots on most KVM VPS.
# `nixinstall` overwrites it with the real one (nixos-generate-config --no-filesystems);
# filesystems come from the template's disko config.
{ lib, ... }:

{
  boot.initrd.availableKernelModules = [
    "ata_piix" "uhci_hcd" "xhci_pci" "ahci" "sd_mod" "sr_mod"
    "virtio_pci" "virtio_scsi" "virtio_blk"
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
