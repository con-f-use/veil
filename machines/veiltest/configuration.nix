{
  lib,
  pkgs,
  config,
  ...
}:
{
  veil.secrets = {
    user-password = {
      target = "/var/lib/secrets/userpw";
      script = ''
        echo -n this-should-really-come-from-a-password-manager |
          argon2 "$(openssl rand -base64 32)" -id -m 17 -t 3 -p 4 -l 64 -e
      '';
    };
  };

  networking.hostName = "veiltest";

  veil.deployUser = "user";
  users.mutableUsers = false;
  users.users.user = {
    isNormalUser = true;
    hashedPasswordFile = config.veil.secrets.user-password.target;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKnSKUwKbbqQ6x5E5q2aJVWRhTfkH7ovTls6WnkQFnPD confus@confusion"
    ];
  };

  # Dummies for now
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = lib.mkDefault config.system.nixos.release;
  fileSystems."/" = { device = "/dev/null"; fsType = "vfat"; };
  boot.loader.grub.devices = [ "/dev/null" ];
}
