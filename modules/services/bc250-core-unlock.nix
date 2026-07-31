{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.bc250-core-unlock;

  # Boot wrapper: run the unlock, then reboot only on the boot where we flipped
  # the mask (loop-safe -- the "already 0xFF" path never reboots).
  unlockAtBoot = pkgs.writeShellApplication {
    name = "bc250-core-unlock-boot";
    runtimeInputs = [
      cfg.package
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.systemd
    ];
    text = ''
      out=$(bc250-unlock-cores 2>&1) && rc=0 || rc=$?
      printf '%s\n' "$out"
      if [ "$rc" -ne 0 ]; then
        echo "bc250-unlock-cores failed (rc=$rc); not rebooting" >&2
        exit "$rc"
      fi

      # Reboot ONLY when we actually wrote 0x77 -> 0xFF this boot. The success
      # line below is the write path; the "already 0xFF" path prints something
      # else and is skipped, so warm reboots and repeat boots don't loop. The
      # nproc guard is belt-and-suspenders (matched wording is pinned to the rev).
      if printf '%s' "$out" | grep -q "Reboot to bring up all 8 cores" \
         && [ "$(nproc)" -lt 16 ]; then
        echo "core mask set; rebooting so AGESA enumerates all 8 cores"
        systemctl --no-block reboot
      fi
    '';
  };
in
{
  # Standalone service unlocking the BC-250's two factory-disabled CPU cores:
  # 6c/12t -> 8c/16t. Upstream: https://github.com/rw-r-r-0644/bc250-core-unlock
  #
  # The core-presence mask (SMN 0x0115A870) reads 0x77. The host CPU can't write
  # it; only the SMU can, so the unlock abuses SMU queue-3 message 0x98 to set the
  # mask to 0xFF. AGESA then enumerates all 8 cores -- but only on the *next*
  # boot, and the write is volatile: a warm reboot survives, a cold power-off
  # reverts to 0x77. So this runs at boot before the GPU governor grabs the SMU
  # mailbox: on a 0x77 cold boot it writes 0xFF then reboots ONCE; the next boot
  # reads 0xFF and is a no-op. The reboot is gated on actually flipping the mask,
  # so it cannot reboot-loop. `bc250-unlock-cores` is also on PATH for manual use.
  #
  # These cores were factory-disabled; validate them (stress-ng --cpu 16 --verify,
  # watch machine-check exceptions) before trusting them.
  options.services.bc250-core-unlock = {
    enable = lib.mkEnableOption "the BC-250 8-core unlock (6c/12t -> 8c/16t) at boot";
    package = lib.mkPackageOption pkgs [ "bc250" "bc250-core-unlock" ] { };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    systemd.services.bc250-core-unlock = {
      description = "AMD BC-250 CPU core unlock (6c -> 8c; reboots once to enumerate)";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      # Run before anything else touches the SMU mailbox (the GPU governor and, if
      # enabled, the CPU OC service), and before the gaming session so the extra
      # reboot happens before Steam comes up. Ordering against absent units is
      # harmless.
      before = [
        "cyan-skillfish-governor-smu.service"
        "bc250-smu-oc.service"
        "display-manager.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe unlockAtBoot;
      };
    };
  };
}
