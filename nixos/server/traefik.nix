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
        13002
      ];
    };

    services.traefik = {
      enable = true;
      environmentFiles = ["/var/secrets/traefik-env"];
      staticConfigOptions = {
        # Writing Logs to a File
        log = {
          filePath = "/var/lib/traefik/traefik.log";
          level = "DEBUG";
        };
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
            transport.respondingTimeouts.readTimeout = 0;
            forwardedHeaders.insecure = true;
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
            internal-whitelist = {
              ipAllowList = {
                sourceRange = ["10.0.0.0/24" "10.0.16.0/24" "10.0.24.0/24" "10.15.0.0/16" "2001:470:e251::/48" "172.16.0.0/16"];
              };
            };
            authentik = {
              forwardAuth = {
                address = "https://auth.cb-tech.me/outpost.goauthentik.io/auth/traefik";
                trustForwardHeader = true;
                authResponseHeaders = [
                  "X-authentik-username"
                  "X-authentik-groups"
                  "X-authentik-entitlements"
                  "X-authentik-email"
                  "X-authentik-name"
                  "X-authentik-uid"
                  "X-authentik-jwt"
                  "X-authentik-meta-jwks"
                  "X-authentik-meta-outpost"
                  "X-authentik-meta-provider"
                  "X-authentik-meta-app"
                  "X-authentik-meta-version"
                ];
              };
            };
          };
          routers = {
            dashy = {
              rule = "Host(`dash.local.cb-tech.me`)";
              service = "dashy";
              entrypoints = ["websecure"];
              middlewares = ["internal-whitelist"];
              tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
              tls.certResolver = "cloudflare";
            };
            printer = {
              rule = "Host(`printer.local.cb-tech.me`)";
              service = "printer";
              entrypoints = ["websecure"];
              middlewares = ["internal-whitelist"];
              tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
              tls.certResolver = "cloudflare";
            };
            hydra = {
              rule = "Host(`hydra.local.cb-tech.me`)";
              service = "hydra";
              entrypoints = ["websecure"];
              middlewares = ["internal-whitelist"];
              tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
              tls.certResolver = "cloudflare";
            };
            alli = {
              rule = "Host(`alli.local.cb-tech.me`)";
              service = "alli";
              entrypoints = ["websecure"];
              middlewares = ["internal-whitelist"];
              tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
              tls.certResolver = "cloudflare";
            };
            openspeedtest = {
              rule = "Host(`speed.local.cb-tech.me`)";
              service = "openspeedtest";
              entrypoints = ["websecure"];
              middlewares = ["speedtest" "internal-whitelist"];
              tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
              tls.certResolver = "cloudflare";
            };
            librespeed = {
              rule = "Host(`speed2.local.cb-tech.me`)";
              service = "librespeed";
              entrypoints = ["websecure"];
              middlewares = ["speedtest" "internal-whitelist"];
              tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
              tls.certResolver = "cloudflare";
            };
            pve = {
              rule = "Host(`pve.local.cb-tech.me`)";
              service = "pve";
              entrypoints = ["websecure"];
              middlewares = ["internal-whitelist"];
              tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
              tls.certResolver = "cloudflare";
            };
            heliumdash = {
              rule = "Host(`helium.local.cb-tech.me`)";
              service = "heliumdash";
              entrypoints = ["websecure"];
              middlewares = ["internal-whitelist"];
              tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
              tls.certResolver = "cloudflare";
            };
            caddy = {
              rule = "Host(`static.cb-tech.me`)";
              service = "caddy";
              entrypoints = ["websecure"];
              tls.domains = [{main = "static.cb-tech.me";}];
              tls.certResolver = "cloudflare";
            };
          };
          services = {
            dashy = {loadBalancer.servers = [{url = "http://localhost:18080/";}];};
            printer = {loadBalancer.servers = [{url = "http://10.0.0.30/";}];};
            hydra = {loadBalancer.servers = [{url = "http://10.0.0.30:7125";}];};
            alli = {loadBalancer.servers = [{url = "http://10.0.0.30:7126";}];};
            openspeedtest = {loadBalancer.servers = [{url = "http://localhost:13002/";}];};
            librespeed = {loadBalancer.servers = [{url = "http://localhost:13003/";}];};
            pve = {loadBalancer.servers = [{url = "https://10.0.0.6:8006/";}];};
            heliumdash = {loadBalancer.servers = [{url = "https://helium:9090/";}];};
            caddy = {loadBalancer.servers = [{url = "http://localhost:18085/";}];};
          };
        };
      };
    };
  };
}
