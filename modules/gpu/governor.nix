{ config, lib, pkgs, ... }:
let
  cfg = config.hardware.bc250;
  gcfg = cfg.gpu.governor;

  settingsFormat = pkgs.formats.toml { };

  # Baked defaults reproducing the validated BC-250 tuning; the frequency range
  # and safe-point curve come from options, and `settings` is deep-merged last so
  # any advanced key can be overridden.
  baseSettings = {
    timing = {
      intervals = {
        sample = 250;
        adjust = 100000;
      };
      "ramp-rates" = {
        normal = 1;
        burst = 50;
      };
      "burst-samples" = 60;
      "down-events" = 5;
    };

    "gpu-usage" = {
      "fix-metrics" = true;
      method = "busy-flag";
      "flush-every" = 10;
    };

    gpu."set-method" = "smu";

    dbus.enabled = true;

    "frequency-range" = {
      inherit (gcfg.frequencyRange) min max;
    };

    "frequency-thresholds".adjust = 10;

    "load-target" = {
      upper = 0.95;
      lower = 0.80;
    };

    temperature = {
      throttling = 85;
      throttling_recovery = 75;
    };

    "safe-points" = gcfg.safePoints;
  };

  configFile = settingsFormat.generate "cyan-skillfish-governor-smu.toml" (
    lib.recursiveUpdate baseSettings gcfg.settings
  );
in
{
  # Adaptive GPU frequency/voltage governor for the Cyan Skillfish (gfx1013) APU,
  # driving clocks/voltage through the SMU mailbox. It reads GPU load, keeps the
  # clock inside frequency-range, and applies the voltage from the nearest
  # safe-point curve. Upstream: https://github.com/filippor/cyan-skillfish-governor
  options.hardware.bc250.gpu.governor = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      defaultText = lib.literalExpression "config.hardware.bc250.enable";
      description = "Adaptive SMU GPU governor for the BC-250.";
    };

    package = lib.mkPackageOption pkgs [ "bc250" "cyan-skillfish-governor" ] { };

    frequencyRange = {
      min = lib.mkOption {
        type = lib.types.ints.positive;
        default = 350;
        description = "Lower GPU clock bound (MHz) the governor may scale to.";
      };
      max = lib.mkOption {
        type = lib.types.ints.positive;
        default = 2000;
        description = "Upper GPU clock bound (MHz) the governor may scale to.";
      };
    };

    safePoints = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            frequency = lib.mkOption {
              type = lib.types.ints.positive;
              description = "GPU clock (MHz) at this point.";
            };
            voltage = lib.mkOption {
              type = lib.types.ints.positive;
              description = "GPU voltage (mV) applied at this clock.";
            };
          };
        }
      );
      default = [
        {
          frequency = 350;
          voltage = 700;
        }
        {
          frequency = 1200;
          voltage = 700;
        }
        {
          # 843 mV = the measured SMU AVFS floor at 1500 MHz: requesting less is
          # silently clamped up to it.
          frequency = 1500;
          voltage = 850;
        }
        {
          frequency = 2000;
          voltage = 925;
        }
      ];
      description = ''
        Voltage curve (frequency -> voltage) the governor interpolates between and
        scales within {option}`frequencyRange` based on load. These are
        board-specific; validate before lowering voltages.
      '';
    };

    settings = lib.mkOption {
      type = settingsFormat.type;
      default = { };
      description = ''
        Extra governor TOML, deep-merged over the built-in defaults (timing,
        gpu-usage, load-target, temperature, etc.). Escape hatch for advanced
        keys not surfaced as dedicated options.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && gcfg.enable) {
    environment.systemPackages = [ gcfg.package ];

    # Lets the daemon own com.cyanskillfish.Governor on the system bus.
    services.dbus.packages = [ gcfg.package ];

    systemd.services.cyan-skillfish-governor-smu = {
      description = "Cyan Skillfish GPU Governor (SMU)";
      wantedBy = [ "multi-user.target" ];
      after = [
        "systemd-modules-load.service"
        "dbus.service"
      ];
      # fix-metrics bind-mounts a patched gpu_metrics table via mount/umount; a
      # bare unit PATH lacks util-linux, so the spawn would fail with ENOENT.
      path = [ pkgs.util-linux ];
      serviceConfig = {
        ExecStart = "${lib.getExe gcfg.package} ${configFile}";
        Restart = "on-failure";
        RestartSec = 5;
        # Tiny control loop; never let the OOM killer take it.
        OOMScoreAdjust = -1000;
      };
    };
  };
}
