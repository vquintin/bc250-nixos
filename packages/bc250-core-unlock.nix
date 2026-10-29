# Unlock the BC-250's two factory-disabled CPU cores: 6c/12t -> 8c/16t, via an
# SMU queue-3 SMN write to the core-presence mask (0x5A870: 0x77 -> 0xFF).
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
  version = "0-unstable-2026-09-20";

  src = fetchFromGitHub {
    owner = "rw-r-r-0644";
    repo = "bc250-core-unlock";
    rev = "569785a36bd19008f8d83eb91c0b3ee80596c430";
    hash = "sha256-/8ZQJV9AiZ5FSyMBvV/AZh4DDYRJOxI8wkD/c+pTKfk=";
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
