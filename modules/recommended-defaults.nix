{ config, lib, ... }:
let
  cfg = config.hardware.bc250;
in
{
  options.hardware.bc250.useRecommendedDefaults = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Apply the recommended (non-hardware) software tuning for a BC-250 gaming
      box: the `performance` cpufreq governor (schedutil's ramp lag hurt
      frame-time 1% lows here) and the `scx_lavd` sched_ext scheduler. Both are
      set with {option}`lib.mkDefault`, so a host setting can still override
      them. Turn this off to keep the stock scheduler/governor.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.useRecommendedDefaults) {
    powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

    services.scx = {
      enable = lib.mkDefault true;
      scheduler = lib.mkDefault "scx_lavd";
    };
  };
}
