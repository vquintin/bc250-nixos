{ config, lib, ... }:
let
  cfg = config.hardware.bc250;
in
{
  imports = [
    ./services
    ./cpu
    ./gpu
    ./sensors.nix
    ./zswap.nix
  ];

  options.hardware.bc250.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    example = true;
    description = ''
      Enable AMD BC-250 (ASRock BC-250, Oberon / Cyan Skillfish gfx1013) board
      support: the GPU/board baseline (amdgpu, the 6.18 LTS kernel, IOMMU
      disabled, the GTT/TTM tuning the shared 16 GiB memory needs), the SMU GPU
      governor, the CMOS VRAM size, the ACPI C/P-state fix, the nct6687 sensor
      driver, the recommended zswap tuning (once the host defines swap), and the
      recommended scheduler/governor tuning (performance cpufreq governor +
      scx_lavd, both mkDefault). Individual features are toggled under
      {option}`hardware.bc250.cpu.*` and {option}`hardware.bc250.gpu.*`.

      Opt-in, off by default: the 40 CU unlock, the 8-core unlock, and the CPU
      overclock/undervolt. Also left to the host: disk layout and S4 hibernation.
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
