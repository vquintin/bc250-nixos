# Overlay adding the BC-250 support packages under `pkgs.bc250.*`. Exposed as
# `overlays.default` (for standalone use) and consumed by this repo's modules.
final: _prev: {
  bc250 = {
    cyan-skillfish-governor = final.callPackage ./cyan-skillfish-governor { };
    bc250-smu-oc = final.callPackage ./bc250-smu-oc.nix { };
    bc250-core-unlock = final.callPackage ./bc250-core-unlock.nix { };
    bc250-40cu-tools = final.callPackage ./bc250-40cu-tools.nix { };
    bc250-memcfg = final.callPackage ./bc250-memcfg.nix { };
  };
}
