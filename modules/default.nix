{ inputs, ... }:
{
  default = inputs.self.nixosModules.veil;
  veil = import ./veil/default.nix;
}
