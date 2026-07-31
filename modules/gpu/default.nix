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
    # 6.18 LTS: the BC-250 docs recommend a mainline LTS kernel over linux-zen
    # here. Plain assignment (not mkDefault) so it wins over a consumer's
    # Jovian/SteamOS zen default; a consumer can still mkForce another kernel.
    # We lose zen's amdgpu.ignore_min_pcap patch (dropped from mainline in 6.7),
    # so ignore_min_pcap=1 below is inert on this board -- accepted per the docs.
    boot.kernelPackages = pkgs.linuxPackages_6_18;

    boot.kernelParams = [
      "amdgpu.ignore_min_pcap=1"
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
