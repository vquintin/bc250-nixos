{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.bc250;
  ucfg = cfg.cpu.coreUnlock;
in
{
  # Facade: enable the standalone services.bc250-core-unlock and add the
  # validation tool. See that service for the unlock mechanism and the
  # reboot-once rationale. These cores were factory-disabled; validate them
  # (stress-ng --cpu 16 --verify, watch machine-check exceptions) before
  # trusting them.
  options.hardware.bc250.cpu.coreUnlock = {
    enable = lib.mkEnableOption "BC-250 8-core unlock (6c/12t -> 8c/16t) at boot";
    package = lib.mkPackageOption pkgs [ "bc250" "bc250-core-unlock" ] { };
    force = lib.mkEnableOption "the unlock on a non-0x77 core-presence mask (likely defective cores)";
  };

  config = lib.mkIf (cfg.enable && ucfg.enable) {
    services.bc250-core-unlock = {
      enable = true;
      inherit (ucfg) package force;
    };

    # With 8 cores amdgpu reports a bogus GPU clock (pp_dpm_sclk/freq1_input read
    # ~20 MHz); have the governor overlay freq1_input with the SMU's real value.
    services.cyan-skillfish-governor-smu.fixFrequency = lib.mkDefault true;

    # Validate the unlocked cores: stress-ng --cpu 16 --verify.
    environment.systemPackages = [ pkgs.stress-ng ];
  };
}
