{ config, lib, pkgs, ... }:
let
  cfg = config.hardware.bc250;
in
{
  imports = [
    ./cu-unlock.nix
    ./cu-list.nix
    ./vram.nix
    ./diagnostics.nix
    ./governor.nix
  ];

  config = lib.mkIf cfg.enable {
    # Recommended LTS kernel for the BC-250. Plain assignment so it beats a
    # consumer's zen default (mkForce to override).
    boot.kernelPackages = pkgs.linuxPackages_6_18;

    boot.kernelParams = [
      "mitigations=off"

      # gttsize/ttm: size the GTT and TTM page pools for the 16 GiB unified RAM.
      "amdgpu.gttsize=14750"
      "ttm.pages_limit=3776000"
      "ttm.page_pool_size=3776000"

      # IOMMU is unstable on this card and must never come on.
      "amd_iommu=off"
      "iommu=off"
    ];

    hardware = {
      amdgpu = {
        overdrive.enable = true;
        opencl.enable = true;
        initrd.enable = true;
      };
      graphics = {
        enable = lib.mkDefault true;
        extraPackages = [ pkgs.rocmPackages.clr.icd ];
      };
    };

    services.lact.enable = true;

    environment.systemPackages = with pkgs; [
      amdgpu_top
      clinfo
      vulkan-tools # vulkaninfo, for probing GPU state
    ];
  };
}
