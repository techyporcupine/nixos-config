{
  lib,
  pkgs,
  stdenv,
  autoPatchelfHook,
  ...
}:

stdenv.mkDerivation {
  pname = "amdtools";
  version = "1.0";

  src = ./.;

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    pkgs.zlib
  ];

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin

    for file in $src/*; do
      filename=$(basename "$file")
      
      # Skip nix files (like default.nix)
      if [[ "$filename" == *.nix ]]; then
        continue
      fi

      if [[ "$filename" == *.tar.xz ]]; then
        ${pkgs.gnutar}/bin/tar -xJf "$file" -C $out/bin
      elif [[ "$filename" == *.tar.gz ]] || [[ "$filename" == *.tgz ]]; then
        ${pkgs.gnutar}/bin/tar -xzf "$file" -C $out/bin
      elif [[ "$filename" == *.zip ]]; then
        ${pkgs.unzip}/bin/unzip -d $out/bin "$file"
      else
        cp "$file" $out/bin/
      fi
    done

    chmod +x $out/bin/*
  '';

  meta = with lib; {
    description = "AMD graphics tools and scripts";
    license = licenses.unfree;
    platforms = platforms.linux;
  };
}
