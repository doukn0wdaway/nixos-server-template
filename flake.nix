{
  description = "NixOS server template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";
    nixos-anywhere.inputs.disko.follows = "disko";
  };

  outputs = { self, nixpkgs, disko, nixos-anywhere, ... }:
    let
      lib = nixpkgs.lib;
      forAllSystems = lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];

      script = pkgs: name: runtimeInputs: text:
        pkgs.writeShellApplication { inherit name runtimeInputs text; };

      app = drv: {
        type = "app";
        program = lib.getExe drv;
        meta.description = drv.name;
      };

      # Apps of a server flake; they work on the server repo in the current dir
      serverApps = system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          # Wipe the target disk and install. Target: NixOS ISO (nixos@ip) or any Linux with root ssh (kexec).
          install = app (script pkgs "install"
            [ pkgs.openssh pkgs.mkpasswd pkgs.gnused nixos-anywhere.packages.${system}.default ] ''
            if [[ $# -gt 0 && $1 != -* ]]; then target=$1; shift
            else target=nixos@''${SERVER_IP:?usage: nix run .#install -- nixos@<ip>, or set SERVER_IP in .env.enc}; fi

            # Root password for the VNC console: hashed here, only the hash goes to host.nix
            if [[ -n "''${DEFAULT_PASSWORD:-}" ]]; then
              hash=$(printf '%s' "$DEFAULT_PASSWORD" | mkpasswd -m yescrypt -s)
              sed -i "s|hashedPassword = .*;|hashedPassword = \"$hash\";|" host.nix
            elif grep -q 'hashedPassword = null;' host.nix; then
              echo "warning: DEFAULT_PASSWORD is not set, root will have no console password" >&2
            fi

            # Copy our key once so nixos-anywhere doesn't ask for the password on every ssh call
            ssh-copy-id -o StrictHostKeyChecking=accept-new "$target"

            nixos-anywhere \
              --flake .#server \
              --generate-hardware-config nixos-generate-config ./hardware-configuration.nix \
              --target-host "$target" \
              "$@"

            # The installed system has a new host key
            ssh-keygen -R "''${target#*@}" >/dev/null 2>&1 || true

            echo
            echo "Done. Commit hardware-configuration.nix and host.nix, then: ssh root@''${target#*@}"
          '');

          # Rebuild an already installed server from this checkout
          deploy = app (script pkgs "deploy" [ pkgs.nixos-rebuild ] ''
            if [[ $# -gt 0 && $1 != -* ]]; then target=$1; shift
            else target=root@''${SERVER_IP:?usage: nix run .#deploy -- root@<ip>, or set SERVER_IP in .env.enc}; fi
            nixos-rebuild switch --flake .#server --target-host "$target" "$@"
          '');
        };

      # Run a server app with SERVER_IP / DEFAULT_PASSWORD from the repo's .env.enc (sec is from the system)
      withEnv = app: ''
        cd "$(git rev-parse --show-toplevel)"
        if [[ -f .env.enc ]]; then
          exec sec run .env.enc -- nix run .#${app} -- "$@"
        fi
        exec nix run .#${app} -- "$@"
      '';

      # direnv (.envrc) puts these on PATH inside a server repo; without args they target $SERVER_IP
      serverShell = system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in pkgs.mkShell {
          packages = [
            (script pkgs "nixinstall" [ pkgs.git ] (withEnv "install"))
            (script pkgs "nixdeploy" [ pkgs.git ] (withEnv "deploy"))
          ];
        };
    in
    {
      # Everything every server gets
      nixosModules.default = {
        imports = [
          disko.nixosModules.disko
          ./modules/disko.nix
          ./modules/base.nix
        ];
      };

      # Whole outputs of a server flake (see template/flake.nix)
      lib.mkFlake = { modules, specialArgs ? { } }: {
        nixosConfigurations.server = lib.nixosSystem {
          inherit specialArgs;
          modules = [ self.nixosModules.default ] ++ modules;
        };
        apps = forAllSystems serverApps;
        devShells = forAllSystems (system: { default = serverShell system; });
      };

      templates.default = {
        path = ./template;
        description = "NixOS server";
      };

      # nix run github:doukn0wdaway/nixos-server-template -- <hostname> [ip]
      apps = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in rec {
          new = app (script pkgs "new" [ pkgs.git pkgs.gnused ] ''
            name=''${1:?usage: new <hostname> [ip]}
            ip=''${2:-}
            dir=$name
            [[ "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "bad hostname: $name" >&2; exit 1; }
            [[ ! -e "$dir" ]] || { echo "$dir already exists" >&2; exit 1; }

            mkdir -p "$dir"
            cd "$dir"
            nix flake init -t "path:${self}"
            sed -i "s|networking.hostName = \".*\";|networking.hostName = \"$name\";|" host.nix
            # Console password: DEFAULT_PASSWORD from this template's .env.enc, if your key can decrypt it
            pw=$(sec run "${self}/.env.enc" -- printenv DEFAULT_PASSWORD 2>/dev/null) || pw=
            tmp=$(mktemp -d)
            printf 'SERVER_IP=%s\nDEFAULT_PASSWORD=%s\n' "$ip" "$pw" > "$tmp/.env"
            sec enc "$tmp/.env" .env.enc
            rm -rf "$tmp"
            git init -q
            git add -A

            echo
            echo "Created $dir. Next:"
            echo "  cd $dir && direnv allow"
            if [[ -z "$ip" && -z "$pw" ]]; then echo "  sec edit .env.enc   # SERVER_IP, DEFAULT_PASSWORD"
            elif [[ -z "$ip" ]]; then echo "  sec edit .env.enc   # SERVER_IP"
            elif [[ -z "$pw" ]]; then echo "  sec edit .env.enc   # DEFAULT_PASSWORD"; fi
            echo "  edit host.nix (disk, ports, docker...)"
            echo "  nixinstall"
          '');
          default = new;
        });

      # The template itself must build
      checks.x86_64-linux.template = (self.lib.mkFlake {
        modules = [ ./template/host.nix ./template/hardware-configuration.nix ];
      }).nixosConfigurations.server.config.system.build.toplevel;
    };
}
