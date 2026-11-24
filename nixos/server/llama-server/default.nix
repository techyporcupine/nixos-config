{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.tp.server.llama-server;
  proxy = cfg.smartProxy;
  routerPort = 5349;
  # With the proxy on, the proxy takes port 5349 and the router moves to 5350,
  # which stays open on the LAN for direct access without alias rewriting.
  internalPort = 5350;
  smart-proxy = pkgs.buildGoModule {
    pname = "smart-proxy";
    version = "0.1.0";
    src = ./smart-proxy;
    vendorHash = null;
  };
in {
  options.tp.server = {
    llama-server = {
      enable = lib.mkEnableOption "Enable llama-server router";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.llama-cpp;
        description = "The llama-cpp package to use.";
      };
      smartProxy = {
        enable = lib.mkEnableOption "a proxy that points one model alias at whichever candidate model is loaded";
        alias = lib.mkOption {
          type = lib.types.str;
          default = "smart";
          description = "Model name clients request; it follows whichever candidate is loaded.";
        };
        candidates = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Preset names the alias may route to, most preferred first.";
        };
        fallback = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Preset used when no candidate is loaded. Defaults to the last candidate.";
        };
        paramMap = lib.mkOption {
          type = lib.types.attrsOf (lib.types.attrsOf (lib.types.attrsOf lib.types.anything));
          default = {};
          example = {
            medium = {
              reasoning_effort = {
                xhigh = "high";
                max = "high";
              };
              "reasoning.effort".xhigh = "high";
            };
          };
          description = ''
            Value substitutions for alias requests, per target model. When a request
            for the alias lands on that model, each listed parameter (dotted path for
            nested fields) whose value matches a key gets the mapped value instead.
          '';
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !proxy.enable || proxy.candidates != [];
        message = "tp.server.llama-server.smartProxy.candidates must not be empty";
      }
    ];

    networking.firewall.allowedTCPPorts = [routerPort] ++ lib.optionals proxy.enable [internalPort];

    users.users.${config.tp.username}.linger = true;

    systemd.user.services.llama-server = {
      enable = true;
      description = "llama-server router for managing llama.cpp models";
      after = ["network.target"];
      wantedBy = ["default.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart =
          if proxy.enable
          then "${cfg.package}/bin/llama-server --models-preset %E/llama-cpp/models.ini --host 0.0.0.0 --port ${toString internalPort} --models-max 4"
          else "${cfg.package}/bin/llama-server --models-preset %E/llama-cpp/models.ini --host 0.0.0.0 --port ${toString routerPort} --models-max 4";
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    systemd.user.services.llama-smart-proxy = lib.mkIf proxy.enable {
      enable = true;
      description = "Routes the ${proxy.alias} model alias to whichever llama-server candidate is loaded";
      after = ["network.target" "llama-server.service"];
      wants = ["llama-server.service"];
      wantedBy = ["default.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.escapeShellArgs ([
            "${smart-proxy}/bin/smart-proxy"
            "-listen"
            "0.0.0.0:${toString routerPort}"
            "-upstream"
            "http://127.0.0.1:${toString internalPort}"
            "-alias"
            proxy.alias
            "-candidates"
            (lib.concatStringsSep "," proxy.candidates)
          ]
          ++ lib.optionals (proxy.fallback != null) ["-fallback" proxy.fallback]
          ++ lib.optionals (proxy.paramMap != {}) [
            "-param-map"
            (pkgs.writeText "smart-proxy-param-map.json" (builtins.toJSON proxy.paramMap))
          ]);
        Restart = "on-failure";
        RestartSec = "2s";
      };
    };

    tp.hm.xdg.configFile = {
      "llama-models.ini" = {
        enable = true;
        source = config.tp.hm.lib.file.mkOutOfStoreSymlink "${config.tp.hm.home.homeDirectory}/nixos-config/nixos/server/llama-server/${config.networking.hostName}-models.ini";
        target = "llama-cpp/models.ini";
      };
    };
  };
}
