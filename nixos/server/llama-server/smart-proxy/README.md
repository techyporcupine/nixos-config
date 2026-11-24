# smart-proxy

A small reverse proxy in front of the llama-server router. Clients request the model name `smart` (configurable) and get whichever candidate model is already loaded, so a client request never starts a slow model swap.

## Why it exists

Nitrogen's GPUs hold one large model at a time. Most days that model is a fast mid-range MoE. Some days you load a slower, smarter dense model for demanding work. A swap takes minutes, and without this proxy any client that names the unloaded model starts one. With the proxy, clients name `smart`, and the model changes only when you switch it on purpose.

## Request handling

The proxy listens on port 5349, the router's former public port. The router itself moves to `0.0.0.0:5350` (reachable on the LAN if you want to open `llama-server` directly without alias rewriting), and the proxy connects to it on `127.0.0.1:5350`. Requests reach the router unchanged, with two exceptions, both limited to requests for `smart`:

- The model name `smart` is replaced with the name of the target model. This applies to the top-level `model` field of a JSON body and to a `model=` query parameter.
- Parameter values listed in the param map for that target are substituted (see below).

The router's management endpoints (`/models`, `/models/*` and `/v1/models`) are never modified. A `POST /models/load {"model":"smart"}` therefore still loads the router's own `smart` preset.

## Choosing the target

The target is the first candidate in priority order that is loaded. If none is loaded, it is the first one loading, and after that the first one sleeping. With no candidate up, the target is the fallback, which defaults to the last candidate.

The proxy learns model status from the router's `/models/sse` event stream and keeps the current target in memory. Requests therefore cost no extra round trip to the router. On every connection to the stream, the proxy also reads `/models` once to catch up. If the connection drops, the proxy keeps the last known status and reconnects with backoff.

## Switching models

Open `http://nitrogen:5349/smart-proxy/` in a browser for a one-click switcher and live view of what the router has loaded, or call the endpoints directly:

```
curl -X POST http://nitrogen:5349/smart-proxy/switch -d '{"model":"smart"}'
curl -X POST http://nitrogen:5349/smart-proxy/switch -d '{"model":"medium"}'
curl http://nitrogen:5349/smart-proxy/status
```

A switch unloads every other candidate, waits until they are gone, and then starts loading the chosen one. The call returns once loading has started. Requests for `smart` that arrive during a switch are held until the old model is unloaded, then sent to the new one. Requests already running on the outgoing model are cut off.

You can also switch with the router's own API, using `/models/unload` followed by `/models/load`. The target follows the router's status events either way. If a `smart` request arrives between your unload and your load, it is sent to the fallback, and the router starts loading the fallback.

## Param map

Models differ in the parameter values they accept. Reasoning effort is the usual example: a client may ask for `xhigh` when the loaded model supports only up to `high`. The param map lists substitutions per target model:

```nix
paramMap.medium = {
  reasoning_effort = { xhigh = "high"; max = "high"; };   # chat completions
  "reasoning.effort".xhigh = "high";                      # Responses API
  temperature."1.5" = 1.0;
};
```

When a `smart` request is sent to `medium`, each listed parameter whose value matches a key is given the mapped value. A dotted path names a nested field. A string value is matched by its text, and any other value by its compact JSON (`1.5`, `true`, `null`). Values with no matching key, parameters missing from the request, requests sent to other targets, and requests that name a model directly are not changed.

## Things to know

- A client that names a candidate directly, such as `medium`, reaches the router unchanged. If that model is not loaded, the router loads it.
- The presets file decides what loads at boot. The candidate with `load-on-startup = true` is the target after a reboot.

## Configuration

The NixOS module in `../default.nix` exposes `tp.server.llama-server.smartProxy`:

```nix
tp.server.llama-server.smartProxy = {
  enable = true;
  alias = "smart";                  # default
  candidates = ["smart" "medium"];  # preset names, most preferred first
  fallback = null;                  # default: last candidate
  paramMap = {};                    # see above
};
```

The binary takes `-listen`, `-upstream`, `-alias`, `-candidates`, `-fallback` and `-param-map` (a JSON file with the same shape as `paramMap`).

## Router contract

The proxy depends on these llama-server router behaviours. Check them after a llama.cpp update if something looks wrong.

- `GET /models` returns `{"data": [{"id": ..., "status": {"value": ...}}]}`.
- `GET /models/sse` emits `data: {"model": ..., "event": ..., "data": {"status": ...}}` lines. The proxy reads the events `status_change`, `model_status`, `model_remove` and `models_reload`.
- Status values are `loaded`, `loading`, `sleeping` and `unloaded`.
- `POST /models/load` and `POST /models/unload` take `{"model": ...}` and return before the load or unload finishes.

## Development

```
go test -race ./...
```

The tests use a fake router that implements the endpoints above. `nix build` runs them as well.
