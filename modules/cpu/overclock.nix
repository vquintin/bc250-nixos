{ config, lib, pkgs, ... }:
let
  cfg = config.hardware.bc250;
  ocfg = cfg.cpu.overclock;

  # bc250-apply reads an INI: [overclock] frequency / scale / max_temperature.
  configFile = pkgs.writeText "bc250-smu-oc.conf" ''
    [overclock]
    frequency = ${toString ocfg.frequency}
    scale = ${toString ocfg.scale}
    max_temperature = ${toString ocfg.maxTemperature}
  '';
in
{
  # Declarative CPU overclock/undervolt via SMU mailbox messages.
  # Upstream: https://github.com/bc250-collective/bc250_smu_oc
  #
  # !!! HARDWARE-DAMAGE RISK !!!  Raising the CPU frequency without a matching
  # undervolt lets the SMU scale Vid unbounded and can *permanently brick* the
  # board. The correct (frequency, scale) pair is board-specific: `scale` is not a
  # voltage, it is a curve-shift whose real value is found empirically by
  # `bc250-detect`, which stress-tests and measures *this* board's actual Vid.
  # There is no safe hardcoded default, so `enable` ships off -- run detection
  # first (the tool is on PATH whenever the board is enabled):
  #
  #   bc250-detect --frequency 3500 --vid 1100 --keep   # stock freq, undervolt
  #   # read the "using scale N" line, then set hardware.bc250.cpu.overclock.
  #
  # frequency = 3500 is stock (freq_min); a stock-frequency run with a negative
  # scale is pure undervolt (no clock increase) and the low-risk starting point.
  options.hardware.bc250.cpu.overclock = {
    enable = lib.mkEnableOption "BC-250 CPU overclock/undervolt applied at boot";

    package = lib.mkPackageOption pkgs [ "bc250" "bc250-smu-oc" ] { };

    frequency = lib.mkOption {
      type = lib.types.ints.between 3500 4500;
      default = 3500;
      example = 3900;
      description = "Max CPU boost clock in MHz (3500 = stock). From `bc250-detect`.";
    };

    scale = lib.mkOption {
      type = lib.types.ints.between (-50) 0;
      default = 0;
      example = -20;
      description = ''
        Frequency/Vid curve shift (0 = stock, more negative = more undervolt).
        NOT a voltage -- determined empirically per board by `bc250-detect` (read
        the "using scale N" line from its output).
      '';
    };

    maxTemperature = lib.mkOption {
      type = lib.types.ints.between 0 100;
      default = 90;
      description = "CPU and GPU thermal limit in °C enforced by the SMU.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Always available so `bc250-detect` can find this board's stable curve.
    environment.systemPackages = [
      ocfg.package
      pkgs.stress
    ];

    systemd.services.bc250-smu-oc = lib.mkIf ocfg.enable {
      description = "AMD BC-250 CPU Overclock";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Runs as root, so bc250-apply writes PCI config space without sudo.
        ExecStart = "${lib.getExe' ocfg.package "bc250-apply"} --apply ${configFile}";
      };
    };
  };
}
