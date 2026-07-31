# Sets the BC-250's UMA frame-buffer (VRAM) size via battery-backed CMOS, without
# a modded BIOS. Upstream: https://github.com/fanoush/bc250_memcfg
# The tool writes the memory-config block the BIOS reads at POST, so a change
# only takes effect on the next reboot. modules/gpu/vram.nix re-asserts it every
# boot so the setting is self-healing (e.g. after a CMOS clear / battery pull).
{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation {
  pname = "bc250-memcfg";
  version = "0-unstable-2026-07-30";

  src = fetchFromGitHub {
    owner = "fanoush";
    repo = "bc250_memcfg";
    rev = "829e8d64f23c5ad1e1d662f4eab488f31e0daa72";
    hash = "sha256-5qOz1b7Rx18Xjg/cLYU6XTVpG0Fcmz9ezCsO59vAyNg=";
  };

  # Upstream Makefile just runs `gcc -Os -s main.cpp -o bc250memcfg`.
  installPhase = ''
    runHook preInstall
    install -Dm755 bc250memcfg $out/bin/bc250memcfg
    runHook postInstall
  '';

  meta = {
    description = "Set BC-250 CMOS BIOS memory configuration (UMA/VRAM size) from Linux";
    homepage = "https://github.com/fanoush/bc250_memcfg";
    license = lib.licenses.unfree; # no license file upstream
    mainProgram = "bc250memcfg";
    platforms = lib.platforms.linux;
  };
}
