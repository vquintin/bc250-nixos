# Unlock the BC-250's two factory-disabled CPU cores: 6c/12t -> 8c/16t, via an
# SMU queue-3 SMN write to the core-presence mask (0x0115A870: 0x77 -> 0xFF).
# Upstream: https://github.com/rw-r-r-0644/bc250-core-unlock
# The boot service that applies it (and reboots once so AGESA enumerates the
# cores) lives in modules/cpu/core-unlock.nix. `bc250-unlock-cores` is the CLI.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  python3,
}:
stdenvNoCC.mkDerivation {
  pname = "bc250-core-unlock";
  version = "0-unstable-2026-07-31";

  src = fetchFromGitHub {
    owner = "rw-r-r-0644";
    repo = "bc250-core-unlock";
    rev = "46c52522c0a037762ed7ce7212528b04b36fca29";
    hash = "sha256-2gLMyXGU/3HJcx2UA1dpS1+jxhdLeoRgacvZn5SP9G4=";
  };

  # python3 on PATH so patchShebangs rewrites the script's `/usr/bin/env python3`
  # to a concrete interpreter (script is pure stdlib).
  nativeBuildInputs = [ python3 ];
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bc250-unlock-cores.py $out/bin/bc250-unlock-cores
    patchShebangs $out/bin/bc250-unlock-cores
    runHook postInstall
  '';

  meta = {
    description = "Unlock the BC-250's two disabled CPU cores via an SMU SMN write";
    homepage = "https://github.com/rw-r-r-0644/bc250-core-unlock";
    license = lib.licenses.mit;
    mainProgram = "bc250-unlock-cores";
    platforms = lib.platforms.linux;
  };
}
