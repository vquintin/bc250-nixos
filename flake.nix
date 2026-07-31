{
  description = "NixOS modules for the AMD BC-250 (Cyan Skillfish gfx1013) board";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        # bc250-memcfg has no upstream license (marked unfree).
        config.allowUnfree = true;
        overlays = [ self.overlays.default ];
      };
    in
    {
      # Packages under pkgs.bc250.*, reusable standalone.
      overlays.default = import ./packages;

      # Aggregate module: import once, toggle via hardware.bc250.*. Applies the
      # overlay so the modules can reach pkgs.bc250.*.
      nixosModules.bc250 = {
        imports = [ ./modules ];
        nixpkgs.overlays = [ self.overlays.default ];
      };
      nixosModules.default = self.nixosModules.bc250;

      packages.${system} = {
        inherit (pkgs.bc250)
          cyan-skillfish-governor
          bc250-smu-oc
          bc250-core-unlock
          bc250-40cu-tools
          bc250-memcfg
          ;
      };

      # `nix flake check` builds every package.
      checks.${system} = self.packages.${system};

      formatter.${system} = pkgs.nixfmt;
    };
}
