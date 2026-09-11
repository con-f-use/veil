{
  lib,
  pkgs,
  config,
  ...
}:
{
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = lib.mkDefault 2048; # MB
      diskSize = lib.mkDefault 5000; # MB
      cores = lib.mkDefault 2;
      graphics = lib.mkDefault false;
      forwardPorts = [
        {
          from = "host";
          host.port = 9922;
          guest.port = 22;
        }
      ];
      mountHostNixStore = true;
      writableStoreUseTmpfs = false;
    };

    # Password-less autologin for root when in local vm
    # This is for convenience and demostration, do not do this in
    # production with actually sensitive secrets
    security.sudo.wheelNeedsPassword = false;
    users.users.root = {
      initialPassword = lib.mkForce null;
      initialHashedPassword = lib.mkForce null;
      hashedPassword = lib.mkForce null;
      hashedPasswordFile = lib.mkForce null;
      password = lib.mkForce "";
      openssh.authorizedKeys.keys = config.users.users.user.openssh.authorizedKeys.keys;
    };
    services.getty.autologinUser = "root";

    services.openssh = {
      enable = lib.mkDefault true;
      settings.PasswordAuthentication = false;
    };

    system.stateVersion = lib.mkDefault config.system.nixos.release;
  };

  # fileSystems = lib.mkDefault { "/" = { device = "nodev"; }; };
  # boot.loader.grub.device = lib.mkDefault "nodev";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

# mkVM = name: {
#   type = "app";
#   program = "${inputs.self.nixosConfigurations.${name}.config.system.build.vm}/bin/run-${
#       inputs.self.nixosConfigurations.${name}.config.networking.hostName
#     }-vm";
# };
# in outputs.apps.${name} = mkVM name;
