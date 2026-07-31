{ config, lib, ... }:
let
  cfg = config.hardware.bc250;
in
{
  imports = [
    ./cpu
    ./gpu
  ];

  options.hardware.bc250.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    example = true;
    description = ''
      Enable AMD BC-250 (ASRock BC-250, Oberon / Cyan Skillfish gfx1013) board
      support: the GPU/board baseline (amdgpu, the 6.18 LTS kernel, IOMMU
      disabled, the GTT/TTM tuning the shared 16 GiB memory needs), the 40 CU
      unlock, the SMU GPU governor, the CMOS VRAM size, the ACPI C/P-state fix,
      and the recommended scheduler/governor tuning (performance cpufreq governor
      + scx_lavd, both mkDefault). Individual features are toggled under
      {option}`hardware.bc250.cpu.*` and {option}`hardware.bc250.gpu.*`.

      Not included (host policy / still experimental): disk layout, S4
      hibernation, and the CPU overclock/undervolt and 8-core unlock (both
      opt-in, off by default).
    '';
  };

  config = lib.mkIf cfg.enable {
    # IOMMU is unstable on this card and must never come on.
    boot.kernelParams = [
      "amd_iommu=off"
      "iommu=off"
    ];

    # Recommended software tuning (mkDefault, host-overridable): the performance
    # cpufreq governor -- schedutil's ramp lag hurt frame-time 1% lows here --
    # and the scx_lavd sched_ext scheduler.
    powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
    services.scx = {
      enable = lib.mkDefault true;
      scheduler = lib.mkDefault "scx_lavd";
    };
  };
}
