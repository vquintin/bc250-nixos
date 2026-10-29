{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.bc250-smu-oc;
in
{
  # Standalone service applying a BC-250 CPU overclock/undervolt at boot via the
  # SMU mailbox. Upstream: https://github.com/bc250-collective/bc250_smu_oc
  # Generic over the config file; hardware.bc250.cpu.overclock is the facade that
  # generates one from declarative frequency/scale/maxTemperature options (with
  # the brick-risk warnings).
  options.services.bc250-smu-oc = {
    enable = lib.mkEnableOption "applying a BC-250 CPU overclock/undervolt at boot via the SMU";

    package = lib.mkPackageOption pkgs [ "bc250" "bc250-smu-oc" ] { };

    configFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        INI config in bc250-apply's format -- an `[overclock]` section with
        `frequency` / `scale` / `max_temperature` -- applied at boot.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    systemd.services.bc250-smu-oc = {
      description = "AMD BC-250 CPU Overclock";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      # The governor drives the same SMU index/data pair (0xB8/0xBC) without
      # locking whole mailbox exchanges, so running concurrently can hit the wrong
      # SMN address (bc250_smu_oc#8). Finish first; the governor then also sets
      # the GPU temperature limit last, deterministically.
      before = [ "cyan-skillfish-governor-smu.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Runs as root, so bc250-apply writes PCI config space without sudo.
        ExecStart = "${lib.getExe' cfg.package "bc250-apply"} --apply ${cfg.configFile}";
      };
    };
  };
}
