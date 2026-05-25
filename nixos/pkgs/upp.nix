{
  lib,
  fetchFromGitHub,
  python3Packages,
}:

python3Packages.buildPythonApplication rec {
  pname = "upp";
  version = "0.2.4";

  pyproject = true;

  build-system = with python3Packages; [
    setuptools
  ];

  src = fetchFromGitHub {
    owner = "sibradzic";
    repo = "upp";
    rev = "3db7f14910211a82f8e2fd2f85cfd9ebbfa7192d";
    sha256 = "0rr428g3nj6a0l1whmbh4j676c8pnbsb9rd08qba14mx8x3mi84n";
  };

  propagatedBuildInputs = with python3Packages; [
    click
  ];

  meta = with lib; {
    description = "Uplift Power Play table editor/parser for AMD Radeon GPUs";
    homepage = "https://github.com/sibradzic/upp";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
