# BC-250 CPU overclock/undervolt via SMU mailbox messages.
# Upstream: https://github.com/bc250-collective/bc250_smu_oc
# NixOS wiring (config + boot service) lives in modules/cpu/overclock.nix.
#
# `bc250-detect` shells out to `stress`, and both entry points self-elevate with
# `sudo` (via /run/wrappers) when not already root.
{
  lib,
  python3Packages,
  fetchFromGitHub,
  stress,
}:
python3Packages.buildPythonApplication {
  pname = "bc250-smu-oc";
  version = "0.1.0-unstable-2026-07-30";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "bc250-collective";
    repo = "bc250_smu_oc";
    rev = "43d6b4c6e38c57bc9ec8908c44675ce7d5fd3d2f";
    hash = "sha256-jUeUUzc0ezs+KrRmJvg9nVR0kWW4T3pAedh8v42Zd1g=";
  };

  build-system = [ python3Packages.setuptools ];

  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [
      stress
      "/run/wrappers"
    ])
  ];

  # No test suite; imports poke real PCI/SMU state.
  doCheck = false;

  meta = {
    description = "BC-250 CPU overclock/undervolt via SMU messages";
    homepage = "https://github.com/bc250-collective/bc250_smu_oc";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
