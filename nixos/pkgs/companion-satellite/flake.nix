{
  description = "Bitfocus Companion Satellite package";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux"; # adjust if needed
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true; # <<< THIS IS THE IMPORTANT PART
    };
  in {
    packages.${system}.default = pkgs.stdenv.mkDerivation rec {
      pname = "companion-satellite";
      version = "4.7.2";

      src = pkgs.fetchurl {
        url = "https://s3.bitfocus.io/builds/companion-satellite/companion-satellite-x64-472-4c684ca.tar.gz";
        sha256 = "sha256-nwYiuqxrileO/H2oCAfTdfmXDJFT0p+5gQ76fXBrkSo=";
      };

      sourceRoot = ".";

      nativeBuildInputs = [pkgs.autoPatchelfHook];

      buildInputs = [
        pkgs.glibc
        pkgs.stdenv.cc.cc
        pkgs.libusb1
        pkgs.udev
        pkgs.gtk3
        pkgs.cairo
        pkgs.pango
        pkgs.glib
        pkgs.xorg.libX11
        pkgs.xorg.libXcomposite
        pkgs.xorg.libXdamage
        pkgs.xorg.libXext
        pkgs.xorg.libXfixes
        pkgs.xorg.libXrandr
        pkgs.xorg.libxcb
        pkgs.dbus
        pkgs.alsa-lib
        pkgs.at-spi2-core
        pkgs.expat
        pkgs.musl
        pkgs.nss
        pkgs.mesa
      ];

      unpackPhase = ''
        tar -xzf $src
      '';

      installPhase = ''
        mkdir -p $out/opt
        cp -r companion-satellite-x64 $out/opt/${pname}

        # Remove prebuilt musl binaries that can't be patched
        find $out -name "*musl*.node" -delete
        find $out -name "libc.musl-*.so.1" -delete

        mkdir -p $out/bin
        ln -s $out/opt/${pname}/satellite $out/bin/companion-satellite
        chmod +x $out/bin/companion-satellite

        # Add a .desktop file
        mkdir -p $out/share/applications
        cat > $out/share/applications/companion-satellite.desktop <<EOF
        [Desktop Entry]
        Name=Companion Satellite
        Comment=Bitfocus Companion Satellite
        Exec=$out/bin/companion-satellite
        Icon=companion-satellite
        Terminal=false
        Type=Application
        Categories=Utility;
        EOF

        # (Optional) Install an icon if you have one
        if [ -f $out/opt/${pname}/icon.png ]; then
          mkdir -p $out/share/icons/hicolor/256x256/apps
          ln -s $out/opt/${pname}/icon.png $out/share/icons/hicolor/256x256/apps/companion-satellite.png
        fi
      '';

      meta = with pkgs.lib; {
        description = "Bitfocus Companion Satellite";
        homepage = "https://bitfocus.io/companion";
        license = licenses.unfree;
        platforms = platforms.linux;
      };
    };
  };
}
