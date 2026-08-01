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

      # A NixOS module bundling the package overlay, so the imported modules can
      # reach pkgs.bc250.* without the consumer wiring the overlay themselves.
      withOverlay = mods: {
        imports = mods;
        nixpkgs.overlays = [ self.overlays.default ];
      };
    in
    {
      # Packages under pkgs.bc250.*, reusable standalone.
      overlays.default = import ./packages;

      nixosModules = {
        # Aggregate: import once, toggle via hardware.bc250.*.
        bc250 = withOverlay [ ./modules ];
        default = self.nixosModules.bc250;

        # The standalone services.* modules, each usable on its own (they bundle
        # the overlay, so services.<tool>.enable works without importing the
        # aggregate). hardware.bc250.* drives these under the hood.
        cyan-skillfish-governor-smu = withOverlay [ ./modules/services/cyan-skillfish-governor.nix ];
        bc250-smu-oc = withOverlay [ ./modules/services/bc250-smu-oc.nix ];
        bc250-core-unlock = withOverlay [ ./modules/services/bc250-core-unlock.nix ];
        bc250-cu-live-manager = withOverlay [ ./modules/services/bc250-cu-live-manager.nix ];
        bc250-memcfg = withOverlay [ ./modules/services/bc250-memcfg.nix ];
      };

      packages.${system} = {
        inherit (pkgs.bc250)
          cyan-skillfish-governor
          bc250-smu-oc
          bc250-core-unlock
          bc250-cu-live-manager
          bc250-40cu-tools
          bc250-memcfg
          ;
      };

      # `nix flake check` builds every package.
      checks.${system} = self.packages.${system};

      formatter.${system} = pkgs.nixfmt;
    };
}
