{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.bc250;
  ucfg = cfg.gpu.cuUnlock;
in
{
  # Facade: the 40 CU unlock. The BC-250's gfx1013 die has 40 physical RDNA2 CUs
  # (20 WGPs, 2 CUs each) but the factory firmware routes only 24. This enables
  # the standalone services.bc250-cu-live-manager, which clears the harvest mask
  # and rewrites the SPI WGP dispatch masks at boot via umr (runtime register
  # writes) -- so it routes all 40 CUs with no kernel rebuild. See that service
  # for the mechanism. Some unlocked CUs may be defective (see the README), so it
  # is opt-in.
  options.hardware.bc250.gpu.cuUnlock = {
    enable = lib.mkEnableOption ''
      the 40 CU unlock -- route all 40 RDNA2 CUs by writing the SPI WGP dispatch
      masks at boot via umr (runtime register writes, no kernel rebuild). Some
      unlocked CUs may be defective (see the README), so it is opt-in'';

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
        Per-shader-array WGP dispatch masks, one 5-bit value (`0x00`..`0x1f`) for
        each of the four shader arrays in order SE0.SH0, SE0.SH1, SE1.SH0,
        SE1.SH1. Each set bit routes one WGP (= 2 CUs); the default `0x1f` x4
        routes all 40 CUs. Clear a bit to leave a defective WGP unrouted (e.g.
        `0x0f` drops WGP4 -> CU8/CU9 on that array) -- this is how you mask a bad
        WGP found via {option}`hardware.bc250.gpu.diagnostics.enable`.
      '';
    };

    package = lib.mkPackageOption pkgs [ "bc250" "bc250-cu-live-manager" ] { };
  };

  config = lib.mkIf (cfg.enable && ucfg.enable) {
    services.bc250-cu-live-manager = {
      enable = true;
      package = ucfg.package;
      masks = ucfg.masks;
    };
  };
}
