# bc250-nixos

NixOS modules and packages for the **AMD BC-250** (ASRock BC-250, "Oberon" APU,
Cyan Skillfish `gfx1013`) — the ex-mining board repurposed as a small RDNA2
gaming/compute box. One import plus a nested `hardware.bc250.*` option tree.

It packages and wires the community tooling documented at
[elektricM/amd-bc250-docs](https://github.com/elektricM/amd-bc250-docs):

On by default with `enable`:

- **amdgpu baseline** — 6.18 LTS kernel, GTT/TTM sizing for the 16 GiB unified
  RAM, IOMMU off.
- **recommended tuning** — performance cpufreq governor + `scx_lavd` scheduler
  (both `mkDefault`).
- **cyan-skillfish GPU governor** — adaptive SMU clock/voltage control.
- **VRAM/UMA size** via CMOS (`bc250_memcfg`), self-healing each boot.
- **ACPI fix** — SSDTs adding the CPU C-/P-states the stock firmware omits.

Opt-in:

- **40 CU unlock** — out-of-tree amdgpu patch exposing all 40 RDNA2 CUs (factory
  firmware masks 16), plus a `disabledCUs` list to mask bad WGPs. Rebuilds the
  kernel.
- **8-core unlock** — SMU core-mask write bringing 6c/12t to 8c/16t.
- **CPU overclock/undervolt** — via SMU (brick risk, see below).
- **40 CU diagnostic/health tools**.

## Usage

```nix
# flake.nix
inputs.bc250.url = "github:vquintin/bc250-nixos";

# a host module
{
  imports = [ inputs.bc250.nixosModules.default ];

  hardware.bc250 = {
    enable = true;                 # baseline + governor + VRAM + ACPI fix
                                   # + performance governor + scx_lavd
    cpu = {
      coreUnlock.enable = true;         # 8c/16t (writes SMU mask, reboots once)
      # overclock = { enable = true; frequency = 3500; scale = -13; };  # see WARNING
    };

    gpu = {
      cuUnlock.enable = true;           # unlock all 40 CUs (rebuilds the kernel)
      vramSizeMiB = 512;                # default
      # disabledCUs = [ "0.0.4" ];      # mask a bad WGP found via diagnostics
      # diagnostics.enable = true;      # cu_map / compute-verify / health tools
      # governor.safePoints = [ ... ];  # override the voltage curve
    };
  };
}
```

The aggregate module applies the package overlay (`pkgs.bc250.*`) itself.
`bc250-memcfg` is unfree (no upstream license), so the consumer must allow
unfree.

## Examples

`examples/` is a standalone flake building two BC-250 raw-efi disk images:

- `nix build .#steamos` — a Jovian/SteamOS gaming image.
- `nix build .#inference` — a headless image serving Vulkan-accelerated `ollama`.

## Warnings

- **`gpu.cuUnlock`** exposes CUs the factory masked, some of which may be
  defective. **Verify the unlock works properly before trusting it**: enable
  `gpu.diagnostics` and run `bc250-compute-verify` (heavy Vulkan compute
  correctness test); mask any bad WGP it finds via `gpu.disabledCUs`
  (`bc250-cu-mask` prints the coordinates). Note: `gpu.disabledCUs` is untested —
  all 40 CUs on my board are healthy, so I never needed to mask any.
- **`cpu.overclock`** can *permanently brick* the board if you raise frequency
  without a matching undervolt. `scale` is a board-specific curve shift, not a
  voltage — find it with `bc250-detect` (on `PATH` whenever the board is
  enabled) before enabling. Ships off.
- **`cpu.coreUnlock`** enables two factory-disabled cores. Validate them
  (`stress-ng --cpu 16 --verify`, watch machine-check exceptions) before
  trusting them. The unlock is volatile: it re-applies and reboots once on each
  cold boot.

## Layout

- `modules/` — plain NixOS modules (`cpu/`, `gpu/`), the `hardware.bc250.*` tree.
- `packages/` — the `pkgs.bc250.*` overlay (governor, smu-oc, core-unlock,
  40cu-tools, memcfg).
- `examples/` — a standalone flake building a SteamOS and a Vulkan-inference
  image.

## Not included

Host policy is left to the consumer — e.g. disk layout, hibernation, and the
OpenCL/ROCm stack.
