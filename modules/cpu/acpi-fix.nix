{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.bc250;

  # The BC-250's stock firmware's idle-state table targets CPU objects it never
  # declares (so it never loads), publishes no P-states (_PSS), and calls a few
  # undefined control methods (ACPI errors at boot). This injects three SSDTs --
  # CPU (C-states), PST (8 P-states, 800 MHz..3.2 GHz) and STUBS (no-op methods)
  # -- via an uncompressed ACPI-override cpio prepended to the initramfs (the
  # kernel reads kernel/firmware/acpi/*.aml from the early initrd before ACPI
  # init). They cover all 16 CPU objects, so they work on stock 6-core and
  # unlocked 8-core boards alike.
  # Upstream: https://github.com/e-tho/bc250-acpi-fix (successor of
  # bc250-collective/bc250-acpi-fix, which only covered the 12 stock threads).
  src = pkgs.fetchFromGitHub {
    owner = "e-tho";
    repo = "bc250-acpi-fix";
    rev = "8a4976284ef5c689908612b2465b25cc30112afe";
    hash = "sha256-GiDABg6ownyhlREmdVkRR29Y0iojsLqYYWuIx/NTd70=";
  };

  acpiOverride =
    pkgs.runCommand "bc250-acpi-override.cpio"
      {
        nativeBuildInputs = [
          pkgs.acpica-tools
          pkgs.cpio
        ];
      }
      ''
        mkdir -p kernel/firmware/acpi
        for t in SSDT-CPU SSDT-PST SSDT-STUBS; do
          iasl -p kernel/firmware/acpi/$t ${src}/$t.dsl
        done
        find kernel | sort | cpio --reproducible -o -H newc > $out
      '';
in
{
  options.hardware.bc250.cpu.acpiFix.enable = lib.mkOption {
    type = lib.types.bool;
    default = cfg.enable;
    defaultText = lib.literalExpression "config.hardware.bc250.enable";
    description = ''
      Inject SSDTs adding CPU C-states (_CST) and P-states (_PSS) the stock
      firmware omits, so the cores idle-sleep and cpufreq can scale (all 16
      threads, so 8-core-unlocked boards too), and stubbing the undefined
      methods behind the boot-time ACPI errors. On by default when
      {option}`hardware.bc250.enable` is set. Disable it on a modded BIOS that
      ships its own ACPI fixes: duplicate tables conflict.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.cpu.acpiFix.enable) {
    # Prepended raw (uncompressed) ahead of the main initramfs, like microcode.
    boot.initrd.prepend = [ "${acpiOverride}" ];
  };
}
