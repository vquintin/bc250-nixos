# bc250-nixos

NixOS modules and packages for the **AMD BC-250** (ASRock BC-250, "Oberon" APU,
Cyan Skillfish `gfx1013`) — the ex-mining board repurposed as a small RDNA2
gaming/compute box. One import plus a nested `hardware.bc250.*` option tree.

> [!NOTE]
> This repo is mostly **vibe-coded** — assembled quickly in an AI-assisted
> session, validated by evaluating/building the configs and running them on my
> own BC-250, not hand-audited line by line. It works here, but read it before
> trusting it on your board. Flagging this up front because some people would
> rather know.

It packages and wires the community tooling documented at
[elektricM/amd-bc250-docs](https://github.com/elektricM/amd-bc250-docs):

On by default with `enable`:

- **amdgpu baseline** — 6.18 LTS kernel, GTT/TTM sizing for the 16 GiB unified
  RAM, IOMMU off.
- **recommended tuning** — performance cpufreq governor + `scx_lavd` scheduler
  (both `mkDefault`).
- **cyan-skillfish GPU governor** — adaptive SMU clock/voltage control.
- **VRAM/UMA size** via CMOS (`bc250_memcfg`), self-healing each boot (rewritten
  only when the CMOS value has drifted).
- **ACPI fix** — SSDTs adding the CPU C-/P-states the stock firmware omits.
- **nct6687 sensors** — out-of-tree driver for the board's Nuvoton Super-I/O
  chip, exposing temps/voltages/fans to lm_sensors.
- **zswap tuning** — lz4/zsmalloc compressed cache in front of disk swap
  (preferred over zram here); auto-applies once the host defines a swap device.

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
      vramSize = 512;                   # VRAM/UMA carve-out (MiB), default
      # gttSize = 14750;                # GTT aperture (MiB); vramSize+gttSize <= 16384
      # disabledCUs = [ "0.0.4" ];      # mask a bad WGP found via diagnostics
      # diagnostics.enable = true;      # cu_map / compute-verify / health tools
    };
  };

  # The governor is on by default; tune its curve on the standalone service:
  # services.cyan-skillfish-governor-smu.safePoints = [ ... ];  # voltage curve
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

- `modules/` — the `hardware.bc250.*` facade tree (`cpu/`, `gpu/`), plus
  `modules/services/` — standalone `services.<tool>.*` modules (the governor,
  smu-oc, core-unlock, memcfg mechanisms) that the facade drives.
- `packages/` — the `pkgs.bc250.*` overlay (governor, smu-oc, core-unlock,
  40cu-tools, memcfg).
- `examples/` — a standalone flake building a SteamOS and a Vulkan-inference
  image.

### Standalone services

The service modules are reusable on their own, without the `hardware.bc250`
aggregate — each is exposed as a flake output that bundles the package overlay:

```nix
imports = [ inputs.bc250.nixosModules.cyan-skillfish-governor-smu ];
services.cyan-skillfish-governor-smu.enable = true;
```

Also `nixosModules.bc250-smu-oc`, `nixosModules.bc250-core-unlock`,
`nixosModules.bc250-memcfg`. Importing one of these alongside the aggregate is
fine (same underlying module, deduplicated).

## Not included

Host policy is left to the consumer — e.g. disk layout, hibernation, and the
OpenCL/ROCm stack.

## Credits

This repo is mostly glue; the hard work belongs to the BC-250 community. The
tools it packages and wires:

- [elektricM/amd-bc250-docs](https://github.com/elektricM/amd-bc250-docs) — the
  community documentation hub this follows.
- [filippor/cyan-skillfish-governor](https://github.com/filippor/cyan-skillfish-governor)
  (`smu` branch) — the adaptive SMU GPU governor.
- [duggasco/bc250-40cu-unlock](https://github.com/duggasco/bc250-40cu-unlock) —
  the 40 CU amdgpu patch and diagnostic/health tools.
- [rw-r-r-0644/bc250-core-unlock](https://github.com/rw-r-r-0644/bc250-core-unlock)
  — the 8-core SMU unlock.
- [bc250-collective/bc250_smu_oc](https://github.com/bc250-collective/bc250_smu_oc)
  — CPU overclock/undervolt via the SMU.
- [bc250-collective/bc250-acpi-fix](https://github.com/bc250-collective/bc250-acpi-fix)
  — the C-/P-state SSDTs.
- [fanoush/bc250_memcfg](https://github.com/fanoush/bc250_memcfg) — CMOS
  VRAM/UMA sizing without a modded BIOS.
- [Fred78290/nct6687d](https://github.com/Fred78290/nct6687d) — the Nuvoton
  NCT6687 sensor driver.
- [sched-ext/scx](https://github.com/sched-ext/scx) — the `scx_lavd` scheduler
  used in the default tuning.

And a nod to
[TesseractCat/bc250-nixos](https://github.com/TesseractCat/bc250-nixos), a
parallel BC-250 NixOS flake I only found late into this session — worth a look,
and the source of a few things adopted here (memcfg write-if-differs, the
governor `Conflicts=`, the `nct6687` driver, and the standalone `services.*`
layout).

## License

The glue in this repo (modules, packaging expressions) is [MIT](LICENSE). The
upstream projects it fetches and wraps keep their own licenses — see each
`packages/*.nix`'s `meta.license` (note `bc250-memcfg` is unfree: no upstream
license).
