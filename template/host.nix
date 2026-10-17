# Everything specific to this server. Plain NixOS options;
# split into ./modules/* and import here when it grows.
{ pkgs, lib, ... }:

{
  networking.hostName = "server";

  # lsblk on the target; usually /dev/vda (KVM) or /dev/sda
  disko.devices.disk.main.device = "/dev/vda";

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAnALYyxNVrBvyyqk0sQwfg2f/6UcrP/tYwT9438mLib alex@wsl"
    ];
    # VNC console login; filled in by `nixinstall` from $DEFAULT_PASSWORD
    hashedPassword = null;
  };

  # virtualisation.docker.enable = true;
  # networking.firewall.allowedTCPPorts = [ 80 443 ];
  # networking.firewall.allowedUDPPorts = [ 51820 ];
  # environment.systemPackages = [ pkgs.ffmpeg ];

  # imports = [ ./modules/traefik ];

  system.stateVersion = "26.05";
}
