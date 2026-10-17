# Typical settings for every server. Per-server stuff goes to host.nix.
{ config, lib, pkgs, modulesPath, ... }:

{
  # nixos-generate-config sometimes misdetects KVM (e.g. as Hyper-V); virtio drivers never hurt
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  # grub devices come from disko (the EF02 partition)
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    timeoutStyle = "hidden";
  };
  boot.loader.timeout = lib.mkDefault 0;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users = [ "root" "@wheel" ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = lib.mkDefault "prohibit-password";
      PasswordAuthentication = lib.mkDefault false;
    };
  };

  networking.firewall.enable = true;
  zramSwap.enable = true;
  services.journald.extraConfig = "SystemMaxUse=500M";

  environment.systemPackages = with pkgs; [
    neovim
    kitty.terminfo
    btop
    tmux
    git
    curl
    wget
  ] ++ lib.optional config.virtualisation.docker.enable docker-compose;

  virtualisation.oci-containers.backend = lib.mkIf config.virtualisation.docker.enable "docker";
}
