{pkgs, ...}: {
  # TODO: Figure out what this is doing here and if it's really needed and why.
  qt = {
    enable = true;
    style.package = pkgs.lightly-qt;
    style.name = "Lightly";
  };
}