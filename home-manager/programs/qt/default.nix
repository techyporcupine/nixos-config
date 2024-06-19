{pkgs, ...}: {
  qt = {
    enable = true;
    style.package = pkgs.lightly-qt;
    style.name = "Lightly";
  };
}