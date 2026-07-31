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
  # Sets the BC-250's UMA frame-buffer (VRAM) size via battery-backed CMOS,
  # without a modded BIOS. Upstream: https://github.com/fanoush/bc250_memcfg
  # The tool writes the memory-config block the BIOS reads at POST, so a change
  # only takes effect on the *next* reboot; once written it persists in CMOS. The
  # oneshot re-asserts the size every boot so it's self-healing (e.g. after a CMOS
  # clear / battery pull).
  options.hardware.bc250.gpu = {
    vramSizeMiB = lib.mkOption {
      type = lib.types.nullOr (lib.types.ints.between 256 8192);
      default = 512;
      description = ''
        UMA frame-buffer (VRAM) size in MiB, carved from the 16 GiB unified RAM
        and written to CMOS each boot. 16 MiB aligned, >= 256. Set to null to
        leave the CMOS value untouched.
      '';
    };

    memcfgPackage = lib.mkPackageOption pkgs [ "bc250" "bc250-memcfg" ] { };
  };

  config = lib.mkIf (cfg.enable && cfg.gpu.vramSizeMiB != null) {
    # The UMA block is carved in 16 MiB units; a misaligned value would be
    # silently rounded (or rejected) at POST. Catch it at eval time instead.
    assertions = [
      {
        assertion = cfg.gpu.vramSizeMiB == null || lib.mod cfg.gpu.vramSizeMiB 16 == 0;
        message = "hardware.bc250.gpu.vramSizeMiB (${toString cfg.gpu.vramSizeMiB}) must be a multiple of 16 MiB.";
      }
    ];

    environment.systemPackages = [ cfg.gpu.memcfgPackage ];

    systemd.services.bc250-memcfg = {
      description = "Set BC-250 VRAM (UMA_SIZE) to ${toString cfg.gpu.vramSizeMiB} MiB in CMOS";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Port-I/O tool; needs raw I/O to reach the CMOS index/data ports.
        ExecStart = "${lib.getExe cfg.gpu.memcfgPackage} UMA_SIZE ${toString cfg.gpu.vramSizeMiB}";
      };
    };
  };
}
