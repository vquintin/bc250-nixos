{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.bc250;
  lcfg = cfg.gpu.cuLiveUnlock;
in
{
  # Facade: a no-kernel-rebuild alternative to gpu.cuUnlock. Enables the
  # standalone services.bc250-cu-live-manager, which sets the BC-250's SPI WGP
  # dispatch masks at boot via umr (runtime register writes) instead of the
  # out-of-tree amdgpu patch. See that service for the mechanism. Enable this OR
  # gpu.cuUnlock, not both -- they both route the same 40 CUs.
  options.hardware.bc250.gpu.cuLiveUnlock = {
    enable = lib.mkEnableOption ''
      the live 40 CU unlock -- route all 40 RDNA2 CUs by writing the SPI WGP
      dispatch masks at boot via umr (no kernel rebuild). A runtime alternative
      to {option}`hardware.bc250.gpu.cuUnlock`; enable one or the other. Some
      unlocked CUs may be defective (see the README), so it is opt-in'';

    masks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "0x1f"
        "0x1f"
        "0x1f"
        "0x1f"
      ];
      example = [
        "0x1f"
        "0x1f"
        "0x0f"
        "0x1f"
      ];
      description = ''
        Per-shader-array WGP dispatch masks, one 5-bit value (`0x00`..`0x1f`) for
        each of the four shader arrays in order SE0.SH0, SE0.SH1, SE1.SH0,
        SE1.SH1. Each set bit routes one WGP (= 2 CUs); the default `0x1f` x4
        routes all 40 CUs. Clear a bit to leave a defective WGP unrouted -- the
        runtime-unlock counterpart of {option}`hardware.bc250.gpu.disabledCUs`
        (which only applies to the kernel-patch {option}`gpu.cuUnlock` path).
      '';
    };

    package = lib.mkPackageOption pkgs [ "bc250" "bc250-cu-live-manager" ] { };
  };

  config = lib.mkIf (cfg.enable && lcfg.enable) {
    assertions = [
      {
        assertion = !cfg.gpu.cuUnlock.enable;
        message = ''
          hardware.bc250.gpu.cuLiveUnlock and hardware.bc250.gpu.cuUnlock both
          unlock all 40 CUs -- one at runtime via umr, one via an amdgpu kernel
          patch. Enable only one.
        '';
      }
    ];

    services.bc250-cu-live-manager = {
      enable = true;
      package = lcfg.package;
      masks = lcfg.masks;
    };
  };
}
