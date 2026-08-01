{ config, lib, ... }:
let
  cfg = config.hardware.bc250;
in
{
  options.hardware.bc250.gpu.disabledCUs = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [
      "0.0.4"
      "1.0.4"
    ];
    description = ''
      Compute units to disable via the stock `amdgpu.disable_cu=` kernel param,
      each as `shader_engine.shader_array.cu`. This only reaches the base 24 CUs
      the driver enumerates -- to mask a bad WGP among the umr-routed ones, clear
      its bit in {option}`hardware.bc250.gpu.cuUnlock.masks` instead. The
      cyan-skillfish governor is CU-agnostic, so this only masks CUs at the
      driver; it does not feed the governor.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.gpu.disabledCUs != [ ]) {
    boot.kernelParams = [
      "amdgpu.disable_cu=${lib.concatStringsSep "," cfg.gpu.disabledCUs}"
    ];
  };
}
