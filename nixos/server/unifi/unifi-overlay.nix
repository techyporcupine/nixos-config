self: super: let
  unifiVersion = "8.5.6";
  unifiHash = "sha256-ZpCoE8OPb3FcKzf7Nurf9q+g2BpbjZcp1LvWOsV/tpA=";
in {
  unifiCustom = super.unifi.overrideAttrs (attrs: {
    name = "unifi-controller-${unifiVersion}";
    src = self.fetchurl {
      url = "https://dl.ubnt.com/unifi/${unifiVersion}/unifi_sysvinit_all.deb";
      sha256 = unifiHash;
    };
  });
}
