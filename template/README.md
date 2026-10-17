# Server

`host.nix` holds everything about this server: hostname, disk, ports, docker, custom modules (`./modules/*`).
The base config, disk layout and scripts come from the [template](https://github.com/doukn0wdaway/nixos-server-template).

## Installation

**In VNC** (stock NixOS ISO): `passwd`

**From your laptop:**

```sh
nixinstall                 # = nixinstall nixos@$SERVER_IP
git add -A && git commit -m install
```

`nixinstall`/`nixdeploy` (from direnv) = `sec run .env.enc -- nix run .#install`/`.#deploy`.
`.env.enc`: `SERVER_IP` and `DEFAULT_PASSWORD` — its hash becomes the root password for the VNC
console (SSH is key-only; `new` copies it from the template's `.env.enc`, empty means no password). View/edit: `sec cat .env.enc`, `sec edit .env.enc`.
**The disk set in `host.nix` will be wiped.**

Without an ISO, on top of Ubuntu/Debian with root over SSH: `nixinstall root@$SERVER_IP` (kexec; KVM, DHCP, ≥2 GB RAM).

## Updating

```sh
nixdeploy                  # = nix run .#deploy -- root@$SERVER_IP
nix flake update template   # pull in template changes
```

Or automatically on push to `main`: repository variable `VPS_HOST` + secret `VPS_DEPLOY_KEY`.
