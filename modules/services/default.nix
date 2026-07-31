# Standalone `services.*` modules — the reusable mechanism behind the board.
# Each is self-contained and usable without the hardware.bc250 aggregate; the
# hardware.bc250.* options are thin facades that enable these with board
# defaults. The bc250 aggregate applies the package overlay these default to.
{
  imports = [
    ./cyan-skillfish-governor.nix
    ./bc250-smu-oc.nix
    ./bc250-core-unlock.nix
    ./bc250-memcfg.nix
  ];
}
