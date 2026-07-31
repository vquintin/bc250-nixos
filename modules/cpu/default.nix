{ config, lib, ... }:
let
  cfg = config.hardware.bc250;
in
{
  imports = [
    ./acpi-fix.nix
    ./overclock.nix
    ./core-unlock.nix
  ];

  options.hardware.bc250.cpu.enableMitigations = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Keep CPU speculative-execution mitigations on. Defaults to false, which
      adds `mitigations=off` -- this is an always-in-game box where throughput
      matters more than the hardening. Set true to keep the kernel defaults.
    '';
  };

  config = lib.mkIf (cfg.enable && !cfg.cpu.enableMitigations) {
    boot.kernelParams = [ "mitigations=off" ];
  };
}
