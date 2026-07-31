# Diagnostic/health tooling for the 40 CU unlock (the kernel patch itself is
# applied by modules/gpu/cu-unlock.nix). Upstream:
# https://github.com/duggasco/bc250-40cu-unlock
#
#   cu_map                 harvest/enumeration map (+ optional health overlay)
#   bc250-compute-verify   heavy Vulkan compute correctness test (no reboot) --
#                          the actual per-CU health check the suite relies on
#   bc250-cu-health-test   `quick`/`status` work; `start` (20-reboot per-WGP
#                          isolation) does NOT -- it shells out to dracut/
#                          update-initramfs and rewrites /etc/modprobe.d, none of
#                          which apply on NixOS. For per-WGP isolation, drive the
#                          hardware.bc250.gpu.disabledCUs option instead.
#   bc250-cu-mask          prints the disable_cu= line to add if a bad WGP is
#                          found (don't --install: it writes /etc/modprobe.d,
#                          which NixOS ignores)
#   bc250-40cu-benchmark   Vulkan compute throughput benchmark across the CUs
#
# The upstream enable-* installer scripts are intentionally omitted: they rebuild
# amdgpu out-of-tree, which cu-unlock.nix already does via boot.kernelPatches.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  bash,
  coreutils,
  gnused,
  gawk,
  gcc,
  glslang,
  python3,
  vulkan-tools,
  vulkan-headers,
  vulkan-loader,
  libdrm,
}:
stdenvNoCC.mkDerivation {
  pname = "bc250-40cu-tools";
  version = "0-unstable-2026-07-30";

  src = fetchFromGitHub {
    owner = "duggasco";
    repo = "bc250-40cu-unlock";
    rev = "ae7c30c78e253a5e2c6af0e9c090f807b825191c";
    hash = "sha256-cds5/cWQWN0KauU1a0bbwmmls4DCAowgqHRS+bER8fk=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/bc250-40cu $out/bin
    for s in cu_map bc250-compute-verify bc250-cu-health-test \
             bc250-cu-mask bc250-40cu-benchmark; do
      install -m755 scripts/$s.sh $out/libexec/bc250-40cu/$s.sh
    done
    patchShebangs $out/libexec/bc250-40cu

    for s in cu_map bc250-compute-verify bc250-cu-health-test \
             bc250-cu-mask bc250-40cu-benchmark; do
      makeWrapper $out/libexec/bc250-40cu/$s.sh $out/bin/$s \
        --prefix PATH : ${
          lib.makeBinPath [
            bash
            coreutils
            gnused
            gawk
            gcc
            glslang # glslangValidator
            python3
            vulkan-tools
          ]
        } \
        --suffix CPATH : ${vulkan-headers}/include \
        --suffix LIBRARY_PATH : ${
          lib.makeLibraryPath [
            vulkan-loader
            libdrm
          ]
        } \
        --suffix LD_LIBRARY_PATH : ${
          lib.makeLibraryPath [
            vulkan-loader
            libdrm
          ]
        }
    done

    runHook postInstall
  '';

  meta = {
    description = "BC-250 40 CU unlock diagnostic & health-test tools";
    homepage = "https://github.com/duggasco/bc250-40cu-unlock";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
