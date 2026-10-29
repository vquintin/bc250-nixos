{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.bc250;
in
{
  imports = [
    ./cu-unlock.nix
    ./memory.nix
    ./diagnostics.nix
    ./governor.nix
  ];

  config = lib.mkIf cfg.enable {
    # Latest stable kernel: 7.2+ (or 7.1.10+) is the first with both Cyan
    # Skillfish DP audio clock fixes; the 6.18 LTS still drifts ~7 s/hour
    # (amd-bc250-docs troubleshooting/audio). Plain assignment so it beats a
    # consumer's zen default (mkForce to override).
    boot.kernelPackages = pkgs.linuxPackages_latest;

    # GTT/TTM sizing lives in memory.nix, driven by hardware.bc250.gpu.gttSize.

    hardware = {
      amdgpu = {
        overdrive.enable = true;
        initrd.enable = true;
      };
      graphics.enable = lib.mkDefault true;
    };

    environment.systemPackages = with pkgs; [
      amdgpu_top
      vulkan-tools # vulkaninfo, for probing GPU state
    ];
  };
}
