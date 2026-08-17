{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "gpu-fan-control";
  version = "1.0.0";

  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;

  meta = with lib; {
    description = "Lightweight GPU temperature-based fan controller daemon";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
