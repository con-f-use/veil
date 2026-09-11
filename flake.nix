{
  description = "Simple example for declarative secret side-loading with a NixOS module";

  outputs = inputs: {
    packages = builtins.mapAttrs (
      system: pkgs: import ./packages { inherit pkgs inputs; }
    ) inputs.nixpkgs.legacyPackages;

    nixosModules = import ./modules { inherit inputs; };

    # nixosConfigurations = import ./machines { inherit inputs; };  # ToDo!

    formatter = builtins.mapAttrs (system: pkgs: pkgs.nixfmt-tree) inputs.nixpkgs.legacyPackages;
  };

  inputs.nixpkgs.url = "github:Nixos/nixpkgs/nixos-unstable";
}
