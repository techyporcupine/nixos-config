# server-nix — techyporcupine's NixOS flake

Multi-machine NixOS config for a homelab (Framework laptop, VMs, servers). See [readme](readme.md) for install, secure boot, disk encryption details, and hardware descriptions.

## Directory guide

```
flake.nix              # Entry point: defines inputs, mkSystem helper, nixosConfigurations
machines/               # One .nix per host (carbon, boron, helium, etc). Enables features.
nixos/                  # Shared NixOS modules, imported by all machines
├── default.nix         # Aggregator — imports everything below
├── misc-nix.nix        # Nix daemon config, nh, substituters
├── misc-system.nix     # Locale, time, SSH, sound (PipeWire), shell (zsh + starship)
├── user.nix            # User account + home-manager bridge. Defines tp.hm alias.
├── networking.nix      # NetworkManager, Avahi
├── disks.nix           # Bootloader (systemd-boot), Plymouth, kernel
├── gaming.nix          # Steam, Gamescope, GameMode, emulators
├── rtl-sdr.nix         # RTL-SDR + radio tools
├── graphics/           # Sway/Wayland + NVIDIA/AMD GPU config
│   ├── nvidia.nix      # NVIDIA driver + Prime sync for Optimus
│   ├── amd/            # AMD GPU config
│   └── sway/ hypr/ rofi/ kitty.nix waybar.nix mako.nix ...
├── server/             # Self-hosted service modules
│   ├── traefik.nix     # Reverse proxy (Cloudflare DNS challenge, internal whitelist)
│   ├── beszel.nix      # Monitoring (server + client)
│   ├── backups.nix     # Restic backups (client + server)
│   ├── minecraft.nix   # Minecraft server (nix-minecraft flake)
│   ├── authentik.nix   # SSO/auth
│   ├── immich.nix      # Photo management
│   ├── jellyfin.nix    # Media server
│   ├── vaultwarden.nix # Password manager
│   ├── matrix.nix      # Matrix/Synapse
│   ├── plausible.nix   # Analytics
│   ├── grafana.nix     # Dashboards
│   ├── n8n.nix         # Workflow automation
│   ├── home-assistant.nix
│   ├── librenms.nix    # Network monitoring
│   ├── uptime-kuma.nix
│   ├── zipline.nix     # File sharing
│   ├── unifi/          # UniFi controller
│   └── llama-server/   # llama-server config per-host (boron-models.ini, nitrogen-models.ini)
├── pkgs/               # Custom package modules
│   ├── ollama-overlay.nix
│   ├── upp.nix
│   └── companion-satellite/
disko/                  # Declarative disk partitioning, one per host
assets/                 # Screenshots etc.
util/                   # update-llama-version.sh helper
```

## Key patterns

- **`tp.*` namespace**: Every module declares `options.tp.<module>.enable` and is gated by `lib.mkIf cfg.enable`. Machine configs set `tp.<module>.enable = true` to opt in.
- **`tp.hm` alias**: Defined in `nixos/user.nix`, resolves to `config.home-manager.users.<username>` for convenient home-manager access.
- **`tp.server.*`**: Server service modules follow the same enable-gated pattern, often wiring into Traefik's `dynamicConfigOptions` and opening firewall ports.
- **`tp.graphics.nvidia.enable + tp.graphics.nvidia.prime`**: GPU config is controlled per-machine via these booleans.
- **Overlay namespacing**: `stable.*`, `tp.*`, `staging.*`, `master.*` — access packages from other channels (e.g. `pkgs.stable.gpredict`).
- **`services.franken-llama`**: From the `franken-llama` flake. Set `acceleration = "cuda"`, `cudaCapabilities = [...]`, `nativeCpu = true` per machine. Enables `llama-cpp` package.
- **`nh os switch ./`**: Primary deploy command (nix helper tool, configured in `misc-nix.nix`). Runs GC daily, keeps 2d history.
- **Home-manager**: Integrated via `tp.hm.*` path. User config is in `user.nix` with per-machine overrides in machine configs (e.g. `tp.hm.programs.git.settings.user.name`).

## Hosts

You are very likely not on any of the following hosts; do not assume the machine you are on is anything like any of these servers. If you get approval from the user, you can use ssh if you need to read info from the server. But don't make changes, don't install things, don't `pip install`, etc. -- these are production servers, configured declaratively with Nix.

| Host       | Role | Special modules |
|------------|------|----------------|
| carbon     | Framework 13 laptop (user + desktop) | framework-13-7040-amd, lanzaboote, llama |
| beryllium  | Proxmox VM (self-hosted services) | framework-13-7040-amd, lanzaboote, llama |
| boron      | Desktop workstation | lanzaboote, llama, NVIDIA |
| nitrogen   | Server with LLM | lanzaboote, llama, NVIDIA, ROCm |
| helium     | Off-site backup server (Dell Wyse 5070) | (minimal) |
| lithium    | Additional server | (minimal) |
