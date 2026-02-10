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
                sourceRange = ["10.0.0.0/24" "10.15.0.0/16" "172.16.0.0/16"];
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
            pve = {
              rule = "Host(`pve.local.cb-tech.me`)";
              service = "pve";
              entrypoints = ["websecure"];
              middlewares = ["internal-whitelist"];
              tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
              tls.certResolver = "cloudflare";
            };
            llm = {
              rule = "Host(`llm.local.cb-tech.me`)";
              service = "llm";
              entrypoints = ["websecure"];
              middlewares = ["internal-whitelist"];
              tls.domains = [{main = "local.cb-tech.me";} {sans = ["*.local.cb-tech.me"];}];
              tls.certResolver = "cloudflare";
            };
            mesh = {
              rule = "Host(`mesh.cb-tech.me`)";
              service = "mesh";
              entrypoints = ["websecure"];
              tls.domains = [{main = "mesh.cb-tech.me";}];
              tls.certResolver = "cloudflare";
            };
          };
          services = {
            pve = {loadBalancer.servers = [{url = "https://10.0.0.6:8006/";}];};
            llm = {loadBalancer.servers = [{url = "http://10.0.0.11:8080/";}];};
            mesh = {loadBalancer.servers = [{url = "http://10.15.8.10:5920/";}];};
          };
        };
      };
    };
  };
}
