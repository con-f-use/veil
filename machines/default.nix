{ inputs, ... }:
{
  default = inputs.self.nixosConfigurations.veiltest;

  veiltest = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      inputs.self.nixosModules.veil
      ./veiltest/configuration.nix
    ];
  };
}
