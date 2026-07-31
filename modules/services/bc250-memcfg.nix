{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.bc250-memcfg;

  # Per key: read the current value from the CMOS dump and write only when it
  # differs, so a steady-state boot/switch leaves CMOS untouched.
  applyOne = name: value: ''
    req=$(norm ${lib.escapeShellArg (toString value)})
    cur=$(printf '%s\n' "$dump" | grep -E '^${name}=' | cut -d= -f2 || true)
    cur=$(norm "$cur")
    if [ "$cur" = "$req" ]; then
      echo "${name} already $req in CMOS; leaving it."
    else
      echo "Setting ${name} ''${cur:-unknown} -> $req in CMOS."
      bc250memcfg ${name} "$req"
    fi
  '';

  memcfgApply = pkgs.writeShellApplication {
    name = "bc250-memcfg-apply";
    runtimeInputs = [
      cfg.package
      pkgs.gnugrep
      pkgs.coreutils
    ];
    # `bc250memcfg` with no args dumps `KEY=VALUE` lines; a value may carry
    # leading zeros, so normalise decimals (10#) before comparing.
    text = ''
      norm() {
        case "$1" in
          "" | *[!0-9]*) printf '%s' "$1" ;;
          *) printf '%s' "$((10#$1))" ;;
        esac
      }
      dump=$(bc250memcfg || true)
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList applyOne cfg.settings)}
    '';
  };
in
{
  # Standalone service for the BC-250 CMOS memory-config tool: asserts the given
  # CMOS keys (writing only when they drift) at boot and/or on activation. Sets
  # the memory-config block the BIOS reads at POST, so changes take effect on the
  # next reboot; once written they persist in CMOS. Upstream:
  # https://github.com/fanoush/bc250_memcfg
  #
  # hardware.bc250.gpu.vramSize is the facade that drives settings.UMA_SIZE.
  options.services.bc250-memcfg = {
    enable = lib.mkEnableOption "the BC-250 CMOS memory-config tool (bc250memcfg)";

    package = lib.mkPackageOption pkgs [ "bc250" "bc250-memcfg" ] { };

    settings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.int lib.types.str);
      default = { };
      example = {
        UMA_SIZE = 512;
      };
      description = ''
        CMOS memory-config keys to assert -- e.g. `UMA_SIZE` for the VRAM/UMA
        size in MiB. Each is written via bc250memcfg only when the current CMOS
        value differs, per {option}`applyOnBoot` / {option}`applyOnActivation`.
      '';
    };

    applyOnBoot = lib.mkEnableOption "asserting the settings at every boot" // {
      default = true;
    };

    applyOnActivation = lib.mkEnableOption "asserting the settings during nixos-rebuild switch" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { environment.systemPackages = [ cfg.package ]; }

      (lib.mkIf (cfg.applyOnBoot || cfg.applyOnActivation) {
        assertions = [
          {
            assertion = cfg.settings != { };
            message = "services.bc250-memcfg: settings must be non-empty when applyOnBoot or applyOnActivation is enabled.";
          }
        ];
      })

      (lib.mkIf cfg.applyOnActivation {
        # Best-effort: the boot service (when enabled) is the backstop, so a
        # hiccup here (transient port-I/O error) must not fail the activation.
        system.activationScripts.bc250-memcfg.text = ''
          ${lib.getExe memcfgApply} || echo "bc250-memcfg: CMOS update during activation failed; will retry at boot" >&2
        '';
      })

      (lib.mkIf cfg.applyOnBoot {
        systemd.services.bc250-memcfg = {
          description = "Assert BC-250 CMOS memory configuration";
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
