{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.bc250;
in
{
  # Diagnostic/health tooling for the 40 CU unlock: cu_map, bc250-compute-verify
  # (heavy Vulkan compute correctness test), bc250-cu-health-test, bc250-cu-mask
  # (prints bad-WGP coordinates; mask them via hardware.bc250.gpu.cuUnlock.masks).
  options.hardware.bc250.gpu.diagnostics = {
    enable = lib.mkEnableOption "BC-250 40 CU diagnostic & health-test tools";
    package = lib.mkPackageOption pkgs [ "bc250" "bc250-40cu-tools" ] { };
  };

  config = lib.mkIf (cfg.enable && cfg.gpu.diagnostics.enable) {
    environment.systemPackages = [ cfg.gpu.diagnostics.package ];
  };
}
