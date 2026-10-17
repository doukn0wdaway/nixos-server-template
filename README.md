# NixOS server template

Spin up a NixOS server with sensible defaults in one command from your laptop; the only thing
you type in VNC is `passwd`.

Shared parts (base config, disk layout, install and deploy scripts) live in this repo. Each
server's repo holds only what's specific to it (`host.nix`, hardware, `.env.enc`) and pulls
this template in as a flake input.

## What you need on your laptop

- nix with flakes
- direnv (preferably with nix-direnv)
- `sec` in PATH — used to encrypt `.env.enc` (SSH key `~/.ssh/id_ed25519`)

## New server

### 1. Create the repo

```sh
nix run github:doukn0wdaway/nixos-server-template -- myserver 1.2.3.4
cd myserver
direnv allow
```

This creates `./myserver` with the hostname set, runs `git init`, and writes `.env.enc` with
`SERVER_IP` and `DEFAULT_PASSWORD` (copied from this repo's `.env.enc`, if your key can decrypt
it). The IP is optional and can be filled in later.

### 2. Check the password and IP

```sh
sec cat .env.enc    # view
sec edit .env.enc   # change
```

```
SERVER_IP=1.2.3.4
DEFAULT_PASSWORD=...
```

`DEFAULT_PASSWORD` is the root password for the VNC console (SSH login is key-only). `new`
copies it from this repo's `.env.enc`; replace it per server if you like. During installation
it is hashed and the hash is written to `host.nix`. Leave it empty for a passwordless root.

### 3. Edit `host.nix`

- `disko.devices.disk.main.device` — the disk (`lsblk` on the server; usually `/dev/vda` or `/dev/sda`)
- SSH keys, ports, docker, packages — regular NixOS options

### 4. Boot the server from the NixOS ISO and type in VNC

```sh
passwd
```

This sets the password for the `nixos` user in the live system; it's needed once to copy
your SSH key over.

### 5. Install

```sh
nixinstall
```

It copies the key, generates `hardware-configuration.nix`, **wipes the disk**, partitions it,
installs, and reboots. A couple of minutes later:

```sh
ssh root@1.2.3.4
git add -A && git commit -m install
```

## Day to day

```sh
nixdeploy                   # apply host.nix to the server
nix flake update template   # pull in template changes (then nixdeploy)
sec cat .env.enc            # view the IP / password
```

Server-specific modules go in `./modules/...` of the server's repo and are added to `host.nix`
via `imports`. Base values are overridden directly in `host.nix` (use `lib.mkForce` where a
plain override doesn't work).

## Auto-deploy from GitHub

In the server's repo, set the `VPS_HOST` variable (IP) and the `VPS_DEPLOY_KEY` secret (private
key; the public key goes in `host.nix`). Every push to `main` builds the system on the runner
and applies it. Without `VPS_HOST` the job is skipped.

## Troubleshooting

- **Provider has no custom ISO**, but you have Ubuntu/Debian with root over SSH:
  `nixinstall root@1.2.3.4` — nixos-anywhere boots the installer via kexec on its own. Requires
  KVM (not OpenVZ/LXC), ≥2 GB RAM, DHCP preferred. If the server drops off the network before
  the disk is partitioned, rebooting from the provider panel brings back the old system.
- **`REMOTE HOST IDENTIFICATION HAS CHANGED`** after a reinstall: `ssh-keygen -R 1.2.3.4`.
- **One-off different address**: `nixinstall nixos@5.6.7.8`, `nixdeploy root@5.6.7.8`.

## Template layout

- `modules/base.nix` — settings for every server: key-only SSH, flakes, gc, zram, journald, packages, virtio
- `modules/disko.nix` — GPT, boots on both BIOS and UEFI
- `flake.nix` — `lib.mkFlake` (all outputs of a server flake), the `install`/`deploy` apps,
  the `nixinstall`/`nixdeploy` commands for direnv, and the `new` generator
- `template/` — what gets copied into a new server repo

A module needed by several servers goes here as `nixosModules.<name>`; on the server use
`imports = [ inputs.template.nixosModules.<name> ];`.

This repo must be public: servers and their CI fetch it as a flake input.
