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
      Compute units to disable via `amdgpu.disable_cu=`, each as
      `shader_engine.shader_array.cu`. Use after the 40 CU health tools
      ({option}`hardware.bc250.gpu.diagnostics.enable`) turn up a defective WGP
      among the newly-unlocked CUs -- `bc250-cu-mask` prints the coordinates to
      list here. The cyan-skillfish governor is CU-agnostic, so this only masks
      CUs at the driver; it does not feed the governor.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.gpu.disabledCUs != [ ]) {
    boot.kernelParams = [
      "amdgpu.disable_cu=${lib.concatStringsSep "," cfg.gpu.disabledCUs}"
    ];
  };
}
