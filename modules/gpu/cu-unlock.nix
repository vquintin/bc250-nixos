{ config, lib, ... }:
let
  cfg = config.hardware.bc250;
in
{
  # 40 CU unlock: the BC-250's gfx1013 die has 40 physical RDNA2 CUs but the
  # factory firmware soft-masks 16, exposing only 24. This patch clears the
  # harvest mask (CC_GC_SHADER_ARRAY_CONFIG) and enables SPI dispatch to all 5
  # WGPs per shader array during gfx_v10_0_get_cu_info(). Gated on PCI ID 0x13FE
  # (BC-250 only) and the bc250_cc_write_mode module param, so it's inert on any
  # other host sharing this kernel. Rebuilds the kernel from source.
  # Source: https://github.com/duggasco/bc250-40cu-unlock
  options.hardware.bc250.gpu.cuUnlock = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      defaultText = lib.literalExpression "config.hardware.bc250.enable";
      description = ''
        Unlock all 40 RDNA2 compute units (factory firmware exposes 24). Applies
        an out-of-tree amdgpu patch, so it rebuilds the kernel. On by default when
        {option}`hardware.bc250.enable` is set.
      '';
    };

    mode = lib.mkOption {
      type = lib.types.ints.between 0 3;
      default = 3;
      description = ''
        amdgpu.bc250_cc_write_mode: 0 = off (patch default), 3 = clear all shader
        arrays -> enable all 40 CUs.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.gpu.cuUnlock.enable) {
    boot.kernelPatches = [
      {
        name = "bc250-40cu-amdgpu";
        patch = ../../patches/bc250-40cu-amdgpu.patch;
      }
    ];

    boot.kernelParams = [
      "amdgpu.bc250_cc_write_mode=${toString cfg.gpu.cuUnlock.mode}"
    ];
  };
}
