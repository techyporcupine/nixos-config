##### WARNING!!!  #####
### THIS IS A STUB  ###
# IS NOT SET UP FULLY #
#######################
{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.tp.server.authelia;
in {
  options.tp.server.authelia = {
    enable = lib.mkEnableOption "Enable authelia";
  };

  config = lib.mkIf cfg.enable {
    services.authelia.instances.haddock = {
      enable = true;
      settings = {
        theme = "auto";
        authentication_backend.file = {
          path = "/home/${config.tp.username}/authelia/config/users.yml";
          watch = true;
          password = {
            algorithm = "argon2";
            argon2 = {
              variant = "argon2id";
              iterations = 3;
              memory = 65536;
              parallelism = 4;
              key_length = 32;
              salt_length = 16;
            };
          };
        };
        access_control = {
          default_policy = "deny";
          # We want this rule to be low priority so it doesn't override the others
          rules = lib.mkAfter [
            {
              domain = "*.cb-tech.me";
              policy = "one_factor";
            }
          ];
        };
        session = {
          secret = "insecure_session_secret";
          name = "authelia_session";
          same_site = "lax";
          inactivity = "5m";
          expiration = "1h";
          remember_me = "1M";
          cookies = [
            {
              domain = "cb-tech.me";
              authelia_url = "https://auth.cb-tech.me";
              # The period of time the user can be inactive for before the session is destroyed
              inactivity = "1M";
              # The period of time before the cookie expires and the session is destroyed
              expiration = "3M";
              # The period of time before the cookie expires and the session is destroyed
              # when the remember me box is checked
              remember_me = "1y";
            }
          ];
        };
        storage = {
          # encryption_key = "a_very_important_secret";
          local.path = "/home/${config.tp.username}/authelia/config/db.sqlite3";
        };
        notifier.smtp = {
          address = "smtp://smtp.sendgrid.net:587";
          username = "apikey";
          sender = "auth@cb-tech.me";
        };
        log.level = "info";
        #identity_providers.oidc = {
        #  cors = {
        #    endpoints = ["token"];
        #    allowed_origins_from_client_redirect_uris = true;
        #  };
        #  authorization_policies.default = {
        #    default_policy = "one_factor";
        #    rules = [
        #      {
        #        policy = "deny";
        #        subject = "group:lldap_strict_readonly";
        #      }
        #    ];
        #  };
        #};
        # Necessary for Traefik
        server.endpoints.authz.forward-auth.implementation = "ForwardAuth";
      };
      # Templates don't work correctly when parsed from Nix, so our OIDC clients are defined here
      settingsFiles = [./oidc_clients.yaml];
      secrets = {
        jwtSecretFile = secrets."haddock/authelia/jwt_secret".path;
        oidcIssuerPrivateKeyFile = secrets."haddock/authelia/jwks".path;
        oidcHmacSecretFile = secrets."haddock/authelia/hmac_secret".path;
        sessionSecretFile = secrets."haddock/authelia/session_secret".path;
        storageEncryptionKeyFile = secrets."haddock/authelia/storage_encryption_key".path;
      };
      environmentVariables = {
        AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE =
          secrets."haddock/authelia/lldap_authelia_password".path;
        AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = secrets.sendgrid-api-key-authelia.path;
      };
    };

    services.traefik.dynamicConfigOptions = {
      http = {
        middlewares = {
          authelia = {
            forwardAuth.address = "https://localhost:9091/api/authz/forward-auth";
            forwardAuth.trustForwardHeader = "true";
            forwardAuth.authResponseHeaders = "Remote-User,Remote-Groups,Remote-Email,Remote-Name";
          };
        };
      };
    };

    services.traefik.dynamicConfigOptions.http = {
      routers = {
        authelia = {
          rule = "Host(`auth.cb-tech.me`)";
          service = "authelia";
          entrypoints = ["websecure"];
          middlewares = ["authelia"];
          tls.domains = [{main = "auth.cb-tech.me";}];
          tls.certResolver = "cloudflare";
        };
      };
      services.authelia = {loadBalancer.servers = [{url = "http://localhost:9091";}];};
    };
  };
}
