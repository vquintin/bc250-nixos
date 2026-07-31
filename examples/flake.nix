{
  # Example: two BC-250 disk images built on bc250-nixos.
  #   nix build .#steamos     -> a Jovian/SteamOS gaming image
  #   nix build .#inference   -> a headless image serving Vulkan-accelerated ollama
  #
  # Both are raw-efi images (dd to the board's SSD). For local hacking against a
  # checkout, add: --override-input bc250 path:..
  description = "Example BC-250 images (SteamOS + Vulkan inference) on bc250-nixos";

  inputs = {
    bc250.url = "github:vquintin/bc250-nixos";
    nixpkgs.follows = "bc250/nixpkgs";
    jovian.url = "github:Jovian-Experiments/Jovian-NixOS";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      bc250,
      jovian,
      nixos-generators,
      ...
    }:
    let
      system = "x86_64-linux";

      # Shared BC-250 hardware baseline for both images. Boot loader, root fs and
      # partitioning come from the nixos-generators raw-efi format.
      bc250Base = {
        imports = [ bc250.nixosModules.default ];

        # steam and bc250-memcfg are unfree.
        nixpkgs.config.allowUnfree = true;

        hardware.bc250 = {
          enable = true;
          gpu.cuUnlock.enable = true; # all 40 CUs (rebuilds the kernel)
          cpu.coreUnlock.enable = true; # 8c/16t
        };

        system.stateVersion = "25.05";
      };

      mkImage =
        modules:
        nixos-generators.nixosGenerate {
          inherit system modules;
          format = "raw-efi";
        };
    in
    {
      packages.${system} = {
        # 1) SteamOS gaming image via Jovian-NixOS. (For production you may prefer
        # Jovian's pinned nixpkgs channel; this example builds on nixpkgs-unstable
        # for simplicity.)
        steamos = mkImage [
          jovian.nixosModules.default
          bc250Base
          {
            jovian = {
              steam = {
                enable = true;
                autoStart = true;
                user = "player";
                desktopSession = "gamescope-wayland";
              };
              steamos.useSteamOSConfig = true;
            };

            # The Steam Deck UI drives first-time setup through NetworkManager.
            networking.networkmanager.enable = true;

            users.users.player = {
              isNormalUser = true;
              initialPassword = "player"; # example only
              extraGroups = [ "wheel" ];
            };
          }
        ];

        # 2) Headless inference image: ollama served over the network, accelerated
        # through the Vulkan (RADV) backend -- the BC-250's gfx1013 has no reliable
        # ROCm, so Vulkan is the practical path on the unlocked 40 CUs.
        inference = mkImage [
          bc250Base
          (
            { pkgs, ... }:
            {
              services.ollama = {
                enable = true;
                package = pkgs.ollama-vulkan;
                host = "0.0.0.0";
              };
              networking.firewall.allowedTCPPorts = [ 11434 ];
            }
          )
        ];
      };
    };
}
