{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.bc250-cu-live-manager;

  # At boot the oneshot can beat udev creating the amdgpu render node; umr needs
  # it (and debugfs) present before it can touch GPU registers. Mirrors the wait
  # in upstream's own boot unit.
  waitForRenderD = pkgs.writeShellApplication {
    name = "bc250-cu-live-manager-wait-drm";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      for _ in $(seq 1 30); do
        for node in /dev/dri/renderD*; do
          [ -e "$node" ] && exit 0
        done
        sleep 1
      done
      echo "no /dev/dri/renderD* after 30s; amdgpu not ready" >&2
      exit 1
    '';
  };
in
{
  # Standalone service routing the BC-250's CU/WGP dispatch at boot with umr --
  # a no-kernel-rebuild alternative to the amdgpu 40 CU patch
  # (modules/gpu/cu-unlock.nix). Upstream:
  # https://github.com/WinnieLV/bc250-cu-live-manager
  #
  # The gfx1013 die has 40 physical RDNA2 CUs (20 WGPs, 2 CUs each) but the
  # factory firmware routes only 24. This clears the harvest mask
  # (CC_GC_SHADER_ARRAY_CONFIG) and rewrites the SPI static WGP masks
  # (SPI_PG_ENABLE_STATIC_WGP_MASK / RLC_PG_ALWAYS_ON_WGP_MASK) at runtime, so it
  # never compiles the kernel. The writes are volatile -- they re-apply on every
  # boot, so this runs as a plain oneshot with no reboot. Some newly-routed CUs
  # may be defective; validate before trusting them, and drop a WGP's bit from
  # `masks` to leave it unrouted.
  #
  # Generic over the mask table; hardware.bc250.gpu.cuLiveUnlock is the facade.
  # apply-service reads the table from a fixed conf file
  # (/etc/bc250-cu-live-manager.conf), so the module generates that file rather
  # than passing masks on the CLI.
  options.services.bc250-cu-live-manager = {
    enable = lib.mkEnableOption "routing the BC-250 CU/WGP dispatch masks at boot via umr (no kernel rebuild)";

    package = lib.mkPackageOption pkgs [ "bc250" "bc250-cu-live-manager" ] { };

    masks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "0x1f"
        "0x1f"
        "0x1f"
        "0x1f"
      ];
      example = [
        "0x1f"
        "0x1f"
        "0x0f"
        "0x1f"
      ];
      description = ''
        The four per-shader-array WGP dispatch masks, in order SE0.SH0, SE0.SH1,
        SE1.SH0, SE1.SH1. Each is a 5-bit value (`0x00`..`0x1f`) whose set bits
        route WGPs (one WGP = 2 CUs) on that shader array. Written to
        {file}`/etc/bc250-cu-live-manager.conf` as `BC250_WGP_MASKS` and applied
        by the upstream `apply-service` command. The default `0x1f` x4 routes all
        5 WGPs on every array = all 40 CUs; clear a bit to leave a defective WGP
        unrouted (e.g. `0x0f` drops WGP4 -> CU8/CU9).
      '';
    };

    umrInstance = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = null;
      description = ''
        Force a umr DRI instance index instead of autodetecting the BC-250 from
        the `/dev/dri` topology. Leave null unless autodetection picks the wrong
        GPU (multi-GPU hosts).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.length cfg.masks == 4;
        message = "services.bc250-cu-live-manager.masks must have exactly 4 entries (SE0.SH0, SE0.SH1, SE1.SH0, SE1.SH1).";
      }
    ];

    environment.systemPackages = [ cfg.package ];

    # apply-service reads this hardcoded path; it doubles as the unit's
    # EnvironmentFile, so UMR_INSTANCE (when set) is exported to the script too.
    environment.etc."bc250-cu-live-manager.conf".text = ''
      # Managed by the NixOS bc250-cu-live-manager module -- edits are overwritten.
      BC250_WGP_MASKS=${lib.concatStringsSep "," cfg.masks}
    ''
    + lib.optionalString (cfg.umrInstance != null) ''
      UMR_INSTANCE=${toString cfg.umrInstance}
    '';

    systemd.services.bc250-cu-live-manager = {
      description = "AMD BC-250 live CU/WGP unlock (SPI WGP masks via umr; no kernel rebuild)";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      # Route the CUs before the compositor / gaming session comes up. Ordering
      # against an absent display-manager is harmless.
      before = [ "display-manager.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        EnvironmentFile = "-/etc/bc250-cu-live-manager.conf";
        ExecStartPre = lib.getExe waitForRenderD;
        # Runs as root: umr writes GPU registers via debugfs without sudo, and
        # --yes skips the interactive disclaimer/confirmation prompts.
        ExecStart = "${lib.getExe cfg.package} --yes apply-service";
      };
    };
  };
}
