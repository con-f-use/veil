{ inputs, pkgs, ... }:
{
  default = inputs.self.packages.${pkgs.system}.veil;

  veil = pkgs.callPackage ./veil { };
}
