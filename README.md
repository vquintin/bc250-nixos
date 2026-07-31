# bc250-nixos

NixOS modules and packages for the **AMD BC-250** (ASRock BC-250, "Oberon" APU,
Cyan Skillfish `gfx1013`) — the ex-mining board repurposed as a small
RDNA2 gaming/compute box. Modelled on
[Jovian-NixOS](https://github.com/Jovian-Experiments/Jovian-NixOS): one import
plus a nested `hardware.bc250.*` option tree.

It packages and wires the community tooling documented at
[elektricM/amd-bc250-docs](https://github.com/elektricM/amd-bc250-docs):

- **amdgpu baseline** — 6.18 LTS kernel, GTT/TTM sizing for the 16 GiB unified
  RAM, IOMMU off, `lact`.
- **40 CU unlock** — out-of-tree amdgpu patch exposing all 40 RDNA2 CUs (factory
  firmware masks 16), plus a `disabledCUs` list to mask bad WGPs.
- **cyan-skillfish GPU governor** — adaptive SMU clock/voltage control.
- **VRAM/UMA size** via CMOS (`bc250_memcfg`), self-healing each boot.
- **ACPI fix** — SSDTs adding the CPU C-/P-states the stock firmware omits.
- **performance cpufreq governor** (schedutil ramp lag hurts frame times here).
- **CPU overclock/undervolt** via SMU (opt-in — brick risk, see below).
- **8-core unlock** — SMU core-mask write bringing 6c/12t to 8c/16t (opt-in).
- **40 CU diagnostic/health tools** (opt-in).

## Usage

```nix
# flake.nix
inputs.bc250.url = "github:youruser/bc250-nixos";

# a host module
{
  imports = [ inputs.bc250.nixosModules.default ];

  hardware.bc250 = {
    enable = true;                 # baseline + 40 CU + governor + VRAM + ACPI fix

    cpu = {
      # freqGovernor = "performance";     # default
      coreUnlock.enable = true;           # 8c/16t (writes SMU mask, reboots once)
      # overclock = { enable = true; frequency = 3500; scale = -13; };  # see WARNING
    };

    gpu = {
      vramSizeMiB = 512;                  # default
      # disabledCUs = [ "0.0.4" ];        # mask a bad WGP found via diagnostics
      # diagnostics.enable = true;        # cu_map / compute-verify / health tools
      # governor.safePoints = [ ... ];    # override the voltage curve
    };
  };
}
```

The aggregate module applies the package overlay (`pkgs.bc250.*`) itself.
`bc250-memcfg` is unfree (no upstream license), so the consumer must allow
unfree.

## Warnings

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
- `patches/` — the 40 CU amdgpu kernel patch.

## Not included

Host-specific or still-experimental bits are intentionally left to the consumer:
disk layout, S4 hibernation, memory-latency sysctls, Jovian/SteamOS session
policy.
