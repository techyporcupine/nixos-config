{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.matrix;
in {
  options.tp.server.matrix = {
    enable = lib.mkEnableOption "Enable matrix server";
  };

  config = lib.mkIf cfg.enable {
    services.matrix-synapse = {
      enable = true;
      server_name = "matrix.cb-tech.me";
      listeners = [
        {
          port = 8118;
          bind_address = "::1";
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            {
              names = ["client" "federation"];
              compress = false;
            }
          ];
        }
      ];
    };
    services.traefik.dynamicConfigOptions.http = {
      routers = {
        matrix = {
          rule = "Host(`matrix.cb-tech.me`)";
          service = "matrix";
          entrypoints = ["websecure"];
          tls.domains = [{main = "matrix.cb-tech.me";}];
          tls.certResolver = "cloudflare";
        };
      };
      services.matrix = {loadBalancer.servers = [{url = "http://localhost:8118";}];};
    };
  };
}
