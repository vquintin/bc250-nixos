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
  # (prints bad-WGP coordinates; mask them via hardware.bc250.gpu.cuUnlock.masks),
  # plus umr for reading GPU registers by hand. On this ASIC the display block is
  # dcn203 (not dcn201), e.g. `umr -r '*.dcn203.mmDCCG_AUDIO_DTO1_MODULE'` reads
  # 6000000 when the DP audio clock is right; `umr --write` takes hex.
  options.hardware.bc250.gpu.diagnostics = {
    enable = lib.mkEnableOption "BC-250 40 CU diagnostic & health-test tools (plus umr)";
    package = lib.mkPackageOption pkgs [ "bc250" "bc250-40cu-tools" ] { };
  };

  config = lib.mkIf (cfg.enable && cfg.gpu.diagnostics.enable) {
    environment.systemPackages = [
      cfg.gpu.diagnostics.package
      pkgs.umr
    ];
  };
}
