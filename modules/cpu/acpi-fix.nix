{ config, lib, pkgs, ... }:
let
  cfg = config.hardware.bc250;

  # The BC-250's stock firmware ships processor objects (\_PR.P000..P00B) with no
  # _CST (C-states) or _PSS (P-states), so the CPU cores never idle-sleep and
  # cpufreq can't scale them. This injects two SSDTs that add those methods, via
  # an uncompressed ACPI-override cpio prepended to the initramfs (the kernel
  # reads kernel/firmware/acpi/*.aml from the early initrd before ACPI init).
  # Upstream: https://github.com/bc250-collective/bc250-acpi-fix
  # Upstream reports C-states work; P-states are hit-or-miss on this board. Both
  # are loaded anyway -- the PST table is inert if the kernel rejects it.
  src = pkgs.fetchFromGitHub {
    owner = "bc250-collective";
    repo = "bc250-acpi-fix";
    rev = "1594d72f11d674bd7e46f4e51eee4216155e52fb";
    hash = "sha256-eH3Ks7qGyJQAAjSX8IyX/yAFlkqVM9fZHPEY6C//4Lo=";
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
        iasl -p kernel/firmware/acpi/SSDT-CST ${src}/SSDT-CST.dsl
        iasl -p kernel/firmware/acpi/SSDT-PST ${src}/SSDT-PST.dsl
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
      firmware omits, so the cores idle-sleep and cpufreq can scale. On by
      default when {option}`hardware.bc250.enable` is set.
    '';
  };

  config = lib.mkIf cfg.cpu.acpiFix.enable {
    # Prepended raw (uncompressed) ahead of the main initramfs, like microcode.
    boot.initrd.prepend = [ "${acpiOverride}" ];
  };
}
