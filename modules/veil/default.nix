{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [ ./options.nix ];

  config = lib.mkIf (config.veil != { }) {
    environment.systemPackages = [ inputs.self.packages.${pkgs.system}.veil ];
  };
}
