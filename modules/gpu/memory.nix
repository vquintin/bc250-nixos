{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.bc250;

  # The BC-250 has 16 GiB of unified GDDR6 shared by CPU and GPU. VRAM is carved
  # out of it by the BIOS (invisible to the OS); the GTT then maps a slice of the
  # remaining OS RAM for the GPU. So vramSize + gttSize can't exceed the total.
  totalRamMiB = 16 * 1024;

  # amdgpu.gttsize is in MiB; ttm.pages_limit / page_pool_size are in 4 KiB pages
  # (256 pages per MiB). Size the TTM page budget to match the GTT so it can be
  # fully backed.
  gttPages = cfg.gpu.gttSize * 256;

  vramMiB = if cfg.gpu.vramSize == null then 0 else cfg.gpu.vramSize;

  # Read the current UMA_SIZE from CMOS and write only when it differs, so a
  # steady-state boot leaves CMOS untouched instead of rewriting it every time.
  # `bc250memcfg` with no args dumps `KEY=VALUE` lines; the value may carry
  # leading zeros, so normalise it as decimal (10#) before comparing.
  memcfgApply = pkgs.writeShellApplication {
    name = "bc250-memcfg-apply";
    runtimeInputs = [
      cfg.gpu.memcfgPackage
      pkgs.gnugrep
      pkgs.coreutils
    ];
    text = ''
      requested=${toString cfg.gpu.vramSize}
      current=$(bc250memcfg | grep -E '^UMA_SIZE=' | cut -d= -f2 || true)
      if [ -n "$current" ]; then
        current=$((10#$current))
      fi
      if [ "$current" = "$requested" ]; then
        echo "UMA_SIZE already ''${requested} MiB in CMOS; leaving it."
      else
        echo "Setting UMA_SIZE ''${current:-unknown} -> ''${requested} MiB in CMOS."
        bc250memcfg UMA_SIZE "$requested"
      fi
    '';
  };
in
{
  # Sizes the two chunks of the BC-250's 16 GiB unified RAM the GPU cares about:
  #  - vramSize: the dedicated VRAM/UMA carve-out, set in battery-backed CMOS via
  #    bc250_memcfg (no modded BIOS). Upstream: https://github.com/fanoush/bc250_memcfg
  #    The tool writes the memory-config block the BIOS reads at POST, so a change
  #    only takes effect on the *next* reboot; once written it persists in CMOS.
  #    The oneshot re-asserts the size every boot (writing only when it drifted)
  #    so it's self-healing (e.g. after a CMOS clear / battery pull).
  #  - gttSize: the GART/GTT aperture, driving amdgpu.gttsize and the matching TTM
  #    page limits via kernel params.
  options.hardware.bc250.gpu = {
    vramSize = lib.mkOption {
      type = lib.types.nullOr (lib.types.ints.between 256 8192);
      default = 512;
      description = ''
        UMA frame-buffer (VRAM) size in MiB, carved from the 16 GiB unified RAM
        by the BIOS and written to CMOS whenever it drifts from this value. 16
        MiB aligned, >= 256. Set to null to leave the CMOS value untouched.
      '';
    };

    gttSize = lib.mkOption {
      type = lib.types.ints.between 256 totalRamMiB;
      default = 14750;
      description = ''
        GTT (GART) aperture size in MiB -- how much system RAM the GPU may map
        for buffers on top of the dedicated {option}`vramSize` carve-out. Drives
        `amdgpu.gttsize` and the matching `ttm.pages_limit` / `ttm.page_pool_size`
        (gttSize MiB is converted to gttSize * 256 pages of 4 KiB). Together with
        {option}`vramSize` it must fit inside the 16 GiB of unified RAM.
      '';
    };

    memcfgPackage = lib.mkPackageOption pkgs [ "bc250" "bc250-memcfg" ] { };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # Size the GTT aperture and TTM page budget for the unified RAM. TTM limits
        # are in 4 KiB pages; match pages_limit to the GTT so it can be fully
        # backed. page_pool_size (TTM's freed-page recycle cache) is set equal to
        # pages_limit so reclaimed GPU pages get reused instead of being re-fetched
        # and re-flagged WC/UC; it has a shrinker, so the cache is released under
        # memory pressure.
        boot.kernelParams = [
          "amdgpu.gttsize=${toString cfg.gpu.gttSize}"
          "ttm.pages_limit=${toString gttPages}"
          "ttm.page_pool_size=${toString gttPages}"
        ];

        # VRAM is subtracted from RAM at POST and the GTT maps what's left, so the
        # two can't jointly exceed the physical 16 GiB.
        assertions = [
          {
            assertion = vramMiB + cfg.gpu.gttSize <= totalRamMiB;
            message =
              "hardware.bc250.gpu.vramSize + gttSize (${toString vramMiB} + ${toString cfg.gpu.gttSize} = "
              + "${toString (vramMiB + cfg.gpu.gttSize)} MiB) exceeds the board's ${toString totalRamMiB} MiB "
              + "of unified RAM. Lower vramSize and/or gttSize.";
          }
        ];
      }

      (lib.mkIf (cfg.gpu.vramSize != null) {
        # The UMA block is carved in 16 MiB units; a misaligned value would be
        # silently rounded (or rejected) at POST. Catch it at eval time instead.
        assertions = [
          {
            assertion = lib.mod cfg.gpu.vramSize 16 == 0;
            message = "hardware.bc250.gpu.vramSize (${toString cfg.gpu.vramSize}) must be a multiple of 16 MiB.";
          }
        ];

        environment.systemPackages = [ cfg.gpu.memcfgPackage ];

        systemd.services.bc250-memcfg = {
          description = "Set BC-250 VRAM (UMA_SIZE) to ${toString cfg.gpu.vramSize} MiB in CMOS";
          wantedBy = [ "multi-user.target" ];
          after = [ "systemd-modules-load.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            # Port-I/O tool; needs raw I/O to reach the CMOS index/data ports.
            ExecStart = lib.getExe memcfgApply;
          };
        };
      })
    ]
  );
}
