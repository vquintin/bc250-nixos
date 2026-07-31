{
  config,
  lib,
  ...
}:
let
  cfg = config.hardware.bc250;
  haveSwap = config.swapDevices != [ ];
in
{
  # Recommended swap setup for the BC-250: zswap (a compressed RAM cache in front
  # of disk swap), not zram. zram is a poor fit on this board -- it competes with
  # the dynamic VRAM carve-out and can crash memory-hungry games -- and zsmalloc
  # can hold the incompressible GTT pages that get paged out, which zbud can't.
  #
  # zswap needs a physical backing store, and the NixOS module asserts as much,
  # so this only actually turns on once the host defines a swap device. Disk
  # layout / swap is otherwise left to the host, so a swapless consumer is
  # unaffected. Compressor is lz4 (fast, low-latency, good for a slow M.2);
  # zpool/maxPoolPercent fall back to the NixOS module defaults (zsmalloc / 25%
  # on kernels >= 6.3).
  options.hardware.bc250.zswap.enable = lib.mkOption {
    type = lib.types.bool;
    default = cfg.enable;
    defaultText = lib.literalExpression "config.hardware.bc250.enable";
    description = ''
      Apply the recommended zswap tuning (lz4 / zsmalloc compressed cache in
      front of disk swap) for the BC-250. Only takes effect once the host
      defines a swap device ({option}`swapDevices`) -- zswap needs a backing
      store and swap layout is left to the host. On by default when
      {option}`hardware.bc250.enable` is set; every value is mkDefault, so the
      host can override the compressor/pool or disable it outright.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.zswap.enable && haveSwap) {
    boot.zswap = {
      enable = lib.mkDefault true;
      # NixOS default is zstd; lz4 trades a little ratio for lower latency, which
      # is what counts when the backing swap is a PCIe 2.0 x2 M.2.
      compressor = lib.mkDefault "lz4";
    };
  };
}
