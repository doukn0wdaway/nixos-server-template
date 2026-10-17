{
  # base settings, disko, install/deploy, nixinstall: all from the template.
  # `nix flake update template` pulls its latest changes into this server.
  inputs.template.url = "github:doukn0wdaway/nixos-server-template";

  outputs = { template, ... }@inputs:
    template.lib.mkFlake {
      modules = [ ./host.nix ./hardware-configuration.nix ];
      # extra inputs added above are available in modules as `inputs`
      specialArgs = { inherit inputs; };
    };
}
