# server-nix — techyporcupine's NixOS flake

Multi-machine NixOS config for a homelab (Framework laptop, VMs, servers). See [readme](readme.md) for install, secure boot, disk encryption details, and hardware descriptions.

## Directory guide

```
.
├── flake.nix                 # Entry point: defines inputs, mkSystem helper, nixosConfigurations
├── readme.md                 # Install, secure boot, disk encryption, and hardware notes
├── machines/                 # One .nix per host (beryllium, boron, carbon, helium, lithium, nitrogen)
├── nixos/                    # Shared NixOS modules, imported by all machines
│   ├── default.nix           # Aggregator — imports top-level modules and subdirs below
│   ├── misc-nix.nix          # Nix daemon config, nh, substituters
│   ├── misc-system.nix       # Locale, time, SSH, sound (PipeWire), shell (zsh + starship)
│   ├── user.nix              # User account + home-manager bridge. Defines tp.hm alias.
│   ├── networking.nix        # NetworkManager, Avahi
│   ├── disks.nix             # Bootloader (systemd-boot), Plymouth, kernel
│   ├── gaming.nix            # Steam, Gamescope, GameMode, emulators
│   ├── rtl-sdr.nix           # RTL-SDR + radio tools
│   ├── graphics/             # Sway/Wayland, desktop theming, and NVIDIA/AMD GPU config
│   │   ├── default.nix       # Imports graphics submodules below
│   │   ├── graphics.nix      # Base GUI apps, fonts, GVFS, CUPS
│   │   ├── nvidia.nix        # NVIDIA driver + Prime sync for Optimus
│   │   ├── amd/              # AMD GPU tools derivation (amdvbflash, atitool, ohgodatool, wolfamdctrl)
│   │   ├── gpu-fan-control/  # Rust fan controller daemon for AMD MI50
│   │   ├── gpu-optimize.sh   # Power/clock tuning script (RTX 3080 Ti + AMD MI50)
│   │   ├── sway/             # SwayFX desktop config, display profiles, ICC assets
│   │   ├── hypr/             # hypridle, hyprlock configs, and wallpapers
│   │   ├── wofi/             # Wofi launcher config + Catppuccin theme
│   │   ├── mangohud/         # MangoHud config
│   │   ├── gtk.nix           # GTK/GDM theming
│   │   ├── qt.nix            # Qt theming
│   │   ├── kitty.nix         # Kitty terminal config
│   │   ├── waybar.nix        # Waybar status bar
│   │   └── mako.nix          # Mako notification daemon
│   ├── server/               # Self-hosted service modules
│   │   ├── default.nix       # Imports all server modules below
│   │   ├── readme.md         # Notes for beryllium secrets, acme.json, and container dirs
│   │   ├── traefik.nix       # Reverse proxy (Cloudflare DNS challenge, internal whitelist)
│   │   ├── beszel.nix        # Monitoring (server + client)
│   │   ├── backups.nix       # Restic backups (client + server)
│   │   ├── minecraft.nix     # Minecraft server (nix-minecraft flake)
│   │   ├── misc-containers.nix # Podman + OCI containers (Dashy, OpenSpeedTest)
│   │   ├── authentik.nix     # SSO/auth
│   │   ├── immich.nix        # Photo management
│   │   ├── jellyfin.nix      # Media server
│   │   ├── vaultwarden.nix   # Password manager
│   │   ├── matrix.nix        # Matrix/Synapse
│   │   ├── plausible.nix     # Analytics
│   │   ├── grafana.nix       # Dashboards
│   │   ├── n8n.nix           # Workflow automation
│   │   ├── home-assistant.nix
│   │   ├── librenms.nix      # Network monitoring
│   │   ├── uptime-kuma.nix
│   │   ├── zipline.nix       # File sharing
│   │   ├── unifi/            # UniFi controller + unifi-overlay.nix
│   │   └── llama-server/     # llama-server user service + per-host INI (boron-models.ini, nitrogen-models.ini)
│   └── pkgs/                 # Custom package definitions & overlays (not auto-imported)
│       ├── ollama-overlay.nix
│       ├── upp.nix           # Uplift Power Play editor for AMD GPUs
│       └── companion-satellite/
├── disko/                    # Declarative disk partitioning (<host>-disko.nix + placeholder-disko.nix)
├── assets/                   # Screenshots etc.
└── util/                     # update-llama-version.sh helper
```

## Key patterns

- **`tp.*` namespace**: Most modules declare `options.tp.<module>.enable` and are gated by `lib.mkIf cfg.enable`. Machine configs set `tp.<module>.enable = true` to opt in (`user.nix` uses `tp.username`/`tp.fullName`, and `backups`/`beszel` split into `.server`/`.client`).
- **`tp.hm` alias**: Defined in `nixos/user.nix`, resolves to `config.home-manager.users.<username>` for convenient home-manager access.
- **`tp.server.*`**: Server service modules follow the same enable-gated pattern, often wiring into Traefik's `dynamicConfigOptions` and opening firewall ports.
- **`tp.graphics.nvidia.enable` + `tp.graphics.nvidia.prime`**: GPU config is controlled per-machine via these booleans.
- **Overlay namespacing**: `stable.*`, `tp.*`, `staging.*`, `master.*` — access packages from other channels (e.g. `pkgs.stable.gpredict`). `nitrogen` also applies `inputs.kokoro-flake.overlays.default`.
- **`services.franken-llama` & `services.kokoro`**: Imported in `commonModules` via `franken-llama` and `kokoro-flake`. Configure `acceleration` (`"cuda"`, `"dual"`, etc.), `cudaCapabilities`, `rocmTargets`, and `nativeCpu` per machine; enables `llama-cpp`.
- **`nh os switch ./`**: Primary deploy command (nix helper tool, configured in `misc-nix.nix`). Runs GC daily, keeps 2d history.
- **Home-manager**: Integrated via `tp.hm.*` path. User config is in `user.nix` with per-machine overrides in machine configs (e.g. `tp.hm.programs.git.settings.user.name`). Catppuccin homeModule is wired when `homeManagerUser` is set in `flake.nix` (currently `carbon`).

## Hosts

You are very likely not on any of the following hosts; do not assume the machine you are on is anything like any of these servers. If you get approval from the user, you can use ssh if you need to read info from the server. But don't make changes, don't install things, don't `pip install`, etc. -- these are production servers, configured declaratively with Nix.

| Host       | Role | Key features / flake modules |
|------------|------|------------------------------|
| carbon     | Framework 13 laptop (user + desktop) | `framework-13-7040-amd`, `lanzaboote` (in flake; commented out in host), Sway/Wayland, gaming, Tailscale, NetBird |
| beryllium  | Proxmox VM (self-hosted services) | `framework-13-7040-amd`, `lanzaboote` (in flake), Traefik, Authentik, Immich, Jellyfin, Matrix, Vaultwarden, Home Assistant, UniFi, Beszel server, Podman |
| boron      | Desktop workstation (GPU + LLM) | `lanzaboote` (in flake), `franken-llama` (CUDA), `llama-server`, NVIDIA + PRIME, Podman (`open-webui`, `wyoming_openai`, `faster-whisper`) |
| nitrogen   | Headless LLM / AI & NVR server | `lanzaboote` (in flake), `franken-llama` (dual CUDA + ROCm), `llama-server`, `kokoro-flake`, NVIDIA + AMD MI50 (`gpu-optimization`, `gpu-fan-control`), Podman (`frigate` ROCm, `wyoming_openai`, `faster-whisper`) |
| helium     | Off-site backup server (Dell Wyse 5070) | Restic backup server (`tp.server.backups.server`), `beszel` client, monthly `autoUpgrade` |
| lithium    | Additional server | `zipline`, `beszel` client |
