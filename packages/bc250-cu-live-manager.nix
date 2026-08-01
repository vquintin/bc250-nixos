# BC-250 live CU/WGP manager: a self-contained bash tool that reads/writes the
# gfx1013 dispatch registers with umr to route WGPs (2 CUs each) at runtime --
# unlocking all 40 CUs without the out-of-tree amdgpu kernel patch.
# Upstream: https://github.com/WinnieLV/bc250-cu-live-manager
# The boot service that applies a saved mask table lives in
# modules/services/bc250-cu-live-manager.nix; `bc250-cu-live-manager` is the CLI
# (run it with no args for the interactive WGP editor).
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  bash,
  umr,
  pciutils,
  coreutils,
  gnugrep,
  gnused,
  gawk,
  util-linux,
  systemd,
  python3,
  libdrm,
}:
stdenvNoCC.mkDerivation {
  pname = "bc250-cu-live-manager";
  version = "0-unstable-2026-08-01";

  src = fetchFromGitHub {
    owner = "WinnieLV";
    repo = "bc250-cu-live-manager";
    rev = "a929085d791f126ce76a60eb609610820fb08066";
    hash = "sha256-c1+xjMI29vyxIUXsAH9I7aeQ06g/1ZcRzXjlJtru8Fc=";
  };

  nativeBuildInputs = [ makeWrapper ];
  dontConfigure = true;
  dontBuild = true;

  # Wrap the upstream script with its runtime deps on PATH. UMR is set so the
  # script's find_umr() uses this umr instead of hunting /usr/bin, /opt, etc.
  # libdrm is on LD_LIBRARY_PATH for the python topology probe (status /
  # stock-dispatch load libdrm_amdgpu.so.1 via ctypes).
  installPhase = ''
    runHook preInstall

    install -Dm755 bc250-cu-live-manager.sh \
      $out/libexec/bc250-cu-live-manager/bc250-cu-live-manager.sh
    patchShebangs $out/libexec/bc250-cu-live-manager

    makeWrapper $out/libexec/bc250-cu-live-manager/bc250-cu-live-manager.sh \
      $out/bin/bc250-cu-live-manager \
      --set UMR ${lib.getExe' umr "umr"} \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          umr
          pciutils # lspci (BC-250 detection) + setpci (the script's CPU unlock)
          coreutils
          gnugrep
          gnused
          gawk
          util-linux # dmesg, for the enumerated-CU readout
          systemd # systemctl, for the service subcommands
          python3
        ]
      } \
      --suffix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libdrm ]}

    runHook postInstall
  '';

  meta = {
    description = "Set the BC-250's SPI WGP dispatch masks at runtime via umr (no kernel rebuild)";
    homepage = "https://github.com/WinnieLV/bc250-cu-live-manager";
    license = lib.licenses.unfree; # no license file upstream
    mainProgram = "bc250-cu-live-manager";
    platforms = lib.platforms.linux;
  };
}
