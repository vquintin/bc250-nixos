{
  config,
  lib,
  ...
}:
let
  cfg = config.hardware.bc250;
in
{
  # Facade: enable the standalone services.cyan-skillfish-governor-smu with the
  # BC-250 defaults it already ships. Tune the curve / frequency range / advanced
  # keys directly on services.cyan-skillfish-governor-smu.*.
  options.hardware.bc250.gpu.governor.enable = lib.mkOption {
    type = lib.types.bool;
    default = cfg.enable;
    defaultText = lib.literalExpression "config.hardware.bc250.enable";
    description = ''
      Adaptive SMU GPU governor for the BC-250. Turns on
      {option}`services.cyan-skillfish-governor-smu`, whose options carry the
      board-tuned defaults and expose the safe-point curve / frequency range for
      overriding.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.gpu.governor.enable) {
    services.cyan-skillfish-governor-smu.enable = true;
  };
}
