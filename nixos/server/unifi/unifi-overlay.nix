self: super: let
  unifiVersion = "8.5.6";
  unifiHash = "sha256-VwRvU+IHJs6uThdWF0uOqxz4cegBykYzB/fD0/AGPaM=";
in {
  unifiCustom = super.unifi.overrideAttrs (attrs: {
    name = "unifi-controller-${unifiVersion}";
    src = self.fetchurl {
      url = "https://dl.ubnt.com/unifi/${unifiVersion}/unifi_sysvinit_all.deb";
      sha256 = unifiHash;
    };
  });
}
