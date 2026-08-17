{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.tp.server.llama-server;

  warmupScript = pkgs.writeShellApplication {
    name = "llama-warmup";
    runtimeInputs = [pkgs.curl pkgs.coreutils];
    text = ''
      endpoint="http://127.0.0.1:5349"

      # wait for the router itself to answer before asking it for anything
      for _ in $(seq 1 120); do
        if curl -sf -m 5 -o /dev/null "$endpoint/v1/models"; then
          break
        fi
        sleep 1
      done

      for model in ${lib.escapeShellArgs cfg.warmup}; do
        echo "warming $model"
        # a one-token completion blocks until the model is resident, so a
        # successful response is exactly the readiness signal we sequence on.
        # the loop body is serial, which is the whole point.
        if curl -sf -m 900 -o /dev/null \
          -H 'Content-Type: application/json' \
          -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"stream\":false}" \
          "$endpoint/v1/chat/completions"; then
          echo "$model ready"
        else
          echo "WARNING: $model failed to warm; continuing" >&2
        fi
      done
    '';
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
      warmup = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["fast" "smart"];
        description = ''
          Model names to load at startup, strictly in the order given, each one
          waited on until it reports ready before the next is requested.

          This exists because models configured with `fit` size themselves
          against free VRAM measured at load time. Two such models loading
          concurrently each measure a card the other is about to allocate on,
          which makes the resulting split non-deterministic and intermittently
          OOMs. Warming them in a fixed sequence means every model after the
          first measures a settled card.

          Models listed here should NOT also set `load-on-startup` in the
          preset INI, or they will race anyway.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [5349];

    users.users.${config.tp.username}.linger = true;

    systemd.user.services.llama-server = {
      enable = true;
      description = "llama-server router for managing llama.cpp models";
      after = ["network.target"];
      wantedBy = ["default.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/llama-server --models-preset %E/llama-cpp/models.ini --host 0.0.0.0 --port 5349 --models-max 4";
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    systemd.user.services.llama-warmup = lib.mkIf (cfg.warmup != []) {
      enable = true;
      description = "Load llama-server models in a deterministic order";
      # pulled in by llama-server so a restart re-warms, and torn down with it
      after = ["llama-server.service"];
      partOf = ["llama-server.service"];
      wantedBy = ["llama-server.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe warmupScript;
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
