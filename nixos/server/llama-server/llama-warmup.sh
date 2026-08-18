# File: nixos/server/llama-server/llama-warmup.sh
# Purpose: Load llama-server router models in a deterministic order. Each
# model is requested in turn and waited on until it reports ready before the
# next is requested, so models that size themselves against free VRAM (fit)
# always measure a settled card rather than racing another model's load.
#
# Built and run via pkgs.writeShellApplication in default.nix, which supplies
# its own shebang and `set -euo pipefail` -- this file is not run directly.

endpoint="http://127.0.0.1:5349"

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <model> [model...]" >&2
    exit 1
fi

# wait for the router itself to answer before asking it for anything
for _ in $(seq 1 120); do
    if curl -sf -m 5 -o /dev/null "$endpoint/v1/models"; then
        break
    fi
    sleep 1
done

for model in "$@"; do
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
