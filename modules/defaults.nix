{ config, lib, ... }:
let
  cfg = config.hardware.bc250;
in
{
  # Recommended non-hardware software tuning, applied whenever the board is
  # enabled. All mkDefault, so a host setting still overrides:
  #   * performance cpufreq governor -- schedutil's ramp lag hurt frame-time 1%
  #     lows on this board;
  #   * scx_lavd sched_ext scheduler.
  config = lib.mkIf cfg.enable {
    powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

    services.scx = {
      enable = lib.mkDefault true;
      scheduler = lib.mkDefault "scx_lavd";
    };
  };
}
