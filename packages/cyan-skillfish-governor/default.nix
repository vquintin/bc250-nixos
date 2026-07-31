# Adaptive GPU frequency/voltage governor for the BC-250's Cyan Skillfish
# (gfx1013) APU. Upstream: https://github.com/filippor/cyan-skillfish-governor
# (branch "smu", which drives clocks/voltage through the SMU mailbox rather than
# sysfs). The NixOS wiring (config file + systemd unit) lives in
# modules/gpu/governor.nix.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  libdrm,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "cyan-skillfish-governor-smu";
  version = "0.4.0-smu-unstable-2026-07-29";

  src = fetchFromGitHub {
    owner = "filippor";
    repo = "cyan-skillfish-governor";
    rev = "60ab6e5b354f01f287c73d920990dcd618a674cc"; # branch: smu
    hash = "sha256-3XvOVvX0/uvzxnnxS2iP8uaH20V28VIxeQaBljeP4DU=";
  };

  cargoLock.lockFile = ./Cargo.lock;

  # build.rs derives the version from `git describe`, which is unavailable in the
  # sandbox; feed it explicitly so the build is reproducible.
  env.CYAN_SKILLFISH_GOVERNOR_VERSION = finalAttrs.version;

  # libdrm_amdgpu_sys (default features) links -ldrm_amdgpu.
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libdrm ];

  # Tests poke real GPU/DRM state; skip in the build sandbox.
  doCheck = false;

  # Ship the D-Bus policy so the daemon can own its bus name (the module wires
  # services.dbus.packages).
  postInstall = ''
    install -Dm644 com.cyanskillfish.Governor.conf \
      $out/share/dbus-1/system.d/com.cyanskillfish.Governor.conf
  '';

  meta = {
    description = "Adaptive GPU governor for AMD Cyan Skillfish (BC-250) via SMU";
    homepage = "https://github.com/filippor/cyan-skillfish-governor";
    license = lib.licenses.mit;
    mainProgram = "cyan-skillfish-governor-smu";
    platforms = lib.platforms.linux;
  };
})
