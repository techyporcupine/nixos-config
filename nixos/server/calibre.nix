{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.calibre;
in {
  options.tp.server.calibre = {
    enable = lib.mkEnableOption "Enable calibre";
  };

  config = lib.mkIf cfg.enable {
    services.calibre-web = {
      enable = true;
      listen = {
        ip = "127.0.0.1";
        port = 8083;
      };
      options = {
        calibreLibrary = "/var/books/";
        enableBookUploading = true;
        enableBookConversion = true;
      };
    };
    services.traefik.dynamicConfigOptions.http = {
      routers = {
        books = {
          rule = "Host(`books.local.cb-tech.me`)";
          service = "books";
          entrypoints = ["websecure"];
          middlewares = ["internal-whitelist"];
          tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
          tls.certResolver = "cloudflare";
        };
      };
      services.books = {loadBalancer.servers = [{url = "http://localhost:8083";}];};
    };
  };
}
