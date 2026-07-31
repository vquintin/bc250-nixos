{
  config,
  lib,
  ...
}:
let
  cfg = config.hardware.bc250;
in
{
  # The BC-250 carries a Nuvoton NCT6687 Super-I/O chip for board temperatures,
  # voltages and fan tach/PWM. The mainline hwmon drivers don't bind it, so this
  # loads the out-of-tree nct6687d module (built against the running kernel) and
  # force-binds it -- the board isn't in the driver's ACPI/PNP whitelist, so
  # `force=true` is required for the sensors to appear under lm_sensors.
  options.hardware.bc250.sensors.enable = lib.mkOption {
    type = lib.types.bool;
    default = cfg.enable;
    defaultText = lib.literalExpression "config.hardware.bc250.enable";
    description = ''
      Load the nct6687d driver for the BC-250's Nuvoton NCT6687 Super-I/O chip,
      exposing its temperature/voltage/fan sensors (and fan control) to
      lm_sensors. On by default when {option}`hardware.bc250.enable` is set.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.sensors.enable) {
    boot.extraModulePackages = [ config.boot.kernelPackages.nct6687d ];
    boot.kernelModules = [ "nct6687" ];
    boot.extraModprobeConfig = ''
      options nct6687 force=true
    '';
  };
}
