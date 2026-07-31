{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.cyan-skillfish-governor-smu;

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
      inherit (cfg.frequencyRange) min max;
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

    "safe-points" = cfg.safePoints;
  };

  configFile = settingsFormat.generate "cyan-skillfish-governor-smu.toml" (
    lib.recursiveUpdate baseSettings cfg.settings
  );
in
{
  # Standalone service for the Cyan Skillfish (gfx1013 / BC-250) adaptive SMU GPU
  # governor: it reads GPU load, keeps the clock inside frequency-range, and
  # applies the voltage from the nearest safe-point curve, all through the SMU
  # mailbox. Upstream: https://github.com/filippor/cyan-skillfish-governor
  #
  # Usable on its own; hardware.bc250.gpu.governor is a thin facade that enables
  # this with the board defaults below.
  options.services.cyan-skillfish-governor-smu = {
    enable = lib.mkEnableOption "the Cyan Skillfish (gfx1013 / BC-250) adaptive SMU GPU governor";

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
      # Upstream default-config.toml curve
      # (github.com/filippor/cyan-skillfish-governor, smu branch).
      default = [
        {
          frequency = 500;
          voltage = 700;
        }
        {
          frequency = 1000;
          voltage = 800;
        }
        {
          frequency = 1175;
          voltage = 850;
        }
        {
          frequency = 1500;
          voltage = 900;
        }
        {
          frequency = 1600;
          voltage = 910;
        }
        {
          frequency = 1700;
          voltage = 920;
        }
        {
          frequency = 1850;
          voltage = 930;
        }
        {
          frequency = 2000;
          voltage = 960;
        }
      ];
      description = ''
        Voltage curve (frequency -> voltage) the governor interpolates between and
        scales within {option}`frequencyRange` based on load. Defaults to the
        upstream default-config.toml curve; these are board-specific, so validate
        before lowering voltages.
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

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # Lets the daemon own com.cyanskillfish.Governor on the system bus.
    services.dbus.packages = [ cfg.package ];

    systemd.services.cyan-skillfish-governor-smu = {
      description = "Cyan Skillfish GPU Governor (SMU)";
      wantedBy = [ "multi-user.target" ];
      # Only one governor may drive the SMU mailbox; refuse to co-run with the
      # other cyan-skillfish/oberon governor variants a host might have around.
      conflicts = [
        "cyan-skillfish-governor.service"
        "cyan-skillfish-governor-tt.service"
        "oberon-governor.service"
      ];
      after = [
        "systemd-modules-load.service"
        "dbus.service"
      ];
      # fix-metrics bind-mounts a patched gpu_metrics table via mount/umount; a
      # bare unit PATH lacks util-linux, so the spawn would fail with ENOENT.
      path = [ pkgs.util-linux ];
      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} ${configFile}";
        Restart = "on-failure";
        RestartSec = 5;
        # Tiny control loop; never let the OOM killer take it.
        OOMScoreAdjust = -1000;
      };
    };
  };
}
