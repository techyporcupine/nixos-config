{
  config,
  lib,
  ...
}: let
  cfg = config.tp.server.llama-swap;
in {
  options.tp.server = {
    llama-swap.enable = lib.mkEnableOption "Enable llama-swap";
  };

  config = lib.mkIf cfg.enable {
    services.llama-swap = {
      enable = true;
      port = 5349;
      openFirewall = true;
			settings = (import ./${config.networking.hostName}-llama-swap.nix);
    };
  };
}
