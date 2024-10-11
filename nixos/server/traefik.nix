{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.traefik;
in {
  options.tp.server.traefik = {
    enable = lib.mkEnableOption "Enable Traefik";
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = {
      allowedTCPPorts = [
        # Basic HTTP ports
        80
        443
        1443
      ];
    };

    services.traefik = {
      enable = true;
      environmentFiles = ["/var/secrets/traefik-env"];
      staticConfigOptions = {
        entryPoints = {
          web = {
            address = ":80";
            http.redirections.entryPoint = {
              to = "websecure";
              scheme = "https";
            };
          };
          websecure = {
            address = ":443";
            http.tls = {
              certResolver = "cloudflare";
              domains = [
                {
                  main = "local.cb-tech.me";
                  sans = [
                    "*.local.cb-tech.me"
                  ];
                }
              ];
            };
          };
          externalwebsecure = {
            address = ":1443";
          };
        };
        certificatesResolvers = {
          cloudflare = {
            acme = {
              email = "caleb.isaac.bowman@gmail.com";
              storage = "/var/acme.json";
              dnsChallenge = {
                provider = "cloudflare";
                resolvers = ["1.1.1.1:53" "1.0.0.1:53"];
              };
            };
          };
        };
        securityContext.runAsNonRoot = false;

        serversTransport.insecureSkipVerify = true;
        api = {
          dashboard = false;
        };
        global = {
          checknewversion = false;
          sendanonymoususage = false;
        };
      };
      dynamicConfigOptions = {
        http = {
          middlewares = {
            speedtest = {
              buffering.maxRequestBodyBytes = 10000000000;
            };
          };
          routers = {
            dashy = {
              rule = "Host(`dash.local.cb-tech.me`)";
              service = "dashy";
              entrypoints = ["websecure"];
            };
            printer = {
              rule = "Host(`printer.local.cb-tech.me`)";
              service = "printer";
              entrypoints = ["websecure"];
            };
            hydra = {
              rule = "Host(`hydra.local.cb-tech.me`)";
              service = "hydra";
              entrypoints = ["websecure"];
            };
            alli = {
              rule = "Host(`alli.local.cb-tech.me`)";
              service = "alli";
              entrypoints = ["websecure"];
            };
            openspeedtest = {
              rule = "Host(`speed.local.cb-tech.me`)";
              service = "openspeedtest";
              entrypoints = ["websecure"];
              middlewares = ["speedtest"];
            };
            librespeed = {
              rule = "Host(`speed2.local.cb-tech.me`)";
              service = "librespeed";
              entrypoints = ["websecure"];
              middlewares = ["speedtest"];
            };
          };
          services = {
            dashy = {loadBalancer.servers = [{url = "http://localhost:18080/";}];};
            printer = {loadBalancer.servers = [{url = "http://10.0.0.30/";}];};
            hydra = {loadBalancer.servers = [{url = "http://10.0.0.30:7125";}];};
            alli = {loadBalancer.servers = [{url = "http://10.0.0.30:7126";}];};
            openspeedtest = {loadBalancer.servers = [{url = "http://localhost:13002/";}];};
            librespeed = {loadBalancer.servers = [{url = "http://localhost:13003/";}];};
          };
        };
      };
    };
  };
}
