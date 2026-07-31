{ config, lib, ... }:
let
  cfg = config.hardware.bc250;
in
{
  imports = [
    ./acpi-fix.nix
    ./overclock.nix
    ./core-unlock.nix
  ];

  options.hardware.bc250.cpu.freqGovernor = lib.mkOption {
    type = lib.types.str;
    default = "performance";
    example = "schedutil";
    description = ''
      cpufreq governor for the BC-250. Defaults to "performance": schedutil's
      ramp lag hurt frame-time 1% lows in gaming use on this board, and the
      amd-bc250-docs recommend pinning performance. Requires P-states, which
      {option}`hardware.bc250.cpu.acpiFix.enable` provides; without them the
      governor setting is inert. Set another governor here to override.
    '';
  };

  config = lib.mkIf cfg.enable {
    powerManagement.cpuFreqGovernor = lib.mkDefault cfg.cpu.freqGovernor;
  };
}
