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
  version = "0.1.0-unstable-2026-09-27";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "bc250-collective";
    repo = "bc250_smu_oc";
    rev = "327014d6515d7108b1144adfa7203b4cc2eefd0b";
    hash = "sha256-YKzdUiDJRoEubvms263DD6CfaZhj8S5kigOoIS+shfA=";
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
