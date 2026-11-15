# server-nix — techyporcupine's NixOS flake

Multi-machine NixOS config for a homelab (Framework laptop, VMs, servers). See [readme](readme.md) for install, secure boot, disk encryption details, and hardware descriptions.

## Repo map

```
flake.nix                 # Inputs, overlays, mkSystem helper, nixosConfigurations
readme.md                 # Install, secure boot, disk encryption, and hardware notes
machines/<host>.nix       # Per-host config (beryllium, boron, carbon, helium, lithium, nitrogen)
disko/<host>-disko.nix    # Declarative Disko partitioning (+ placeholder-disko.nix)
nixos/                    # Shared modules imported by all hosts via nixos/default.nix
├── core modules          # misc-nix.nix, misc-system.nix, user.nix, networking.nix, disks.nix, gaming.nix, rtl-sdr.nix
├── graphics/             # SwayFX/Wayland desktop (sway/, wofi/, hypr/, theming) & GPU tuning (nvidia.nix, amd/, gpu-fan-control/, gpu-optimize.sh)
├── server/               # Opt-in services (traefik.nix, backups.nix, beszel.nix, misc-containers.nix, llama-server/, unifi/, + app modules)
└── pkgs/                 # Custom packages/overlays NOT auto-imported (upp.nix, ollama-overlay.nix, companion-satellite/)
```

## Key patterns

- **`tp.*` opt-in modules**: Shared modules gate config behind `options.tp.<module>.enable` (except `user.nix`, which keys off `tp.username`, and `backups`/`beszel`, which split `.server`/`.client`).
- **`tp.hm` alias**: Defined in `nixos/user.nix`; resolves to `config.home-manager.users.<username>` for inline home-manager config. Catppuccin `homeModules` only load when `homeManagerUser` is set in `flake.nix` (`carbon`).
- **`tp.server.*` & Traefik**: Server modules typically pair the service with `services.traefik.dynamicConfigOptions` routes and firewall ports.
- **Overlays**: `flake.nix` exposes `pkgs.stable.*`, `pkgs.tp.*`, `pkgs.staging.*`, and `pkgs.master.*` across all hosts (`nitrogen` also adds `inputs.kokoro-flake.overlays.default`).
- **AI / LLM stack**: `franken-llama` (`services.franken-llama`, supporting `"cuda"` or `"dual"` CUDA+ROCm) and `kokoro-flake` (`services.kokoro`) are in `commonModules`. `tp.server.llama-server` loads `nixos/server/llama-server/<host>-models.ini`.
- **Deploy**: `nh os switch ./` (`programs.nh` in `nixos/misc-nix.nix` runs daily GC with 2d retention).

## Hosts

You are very likely not on any of these hosts; treat them as production NixOS machines and only read via SSH with user approval.

| Host      | Role | Key context |
|-----------|------|-------------|
| carbon    | Framework 13 AMD laptop | Daily-driver desktop (SwayFX, gaming, Tailscale/NetBird, Catppuccin HM) |
| beryllium | Proxmox VM | Primary self-hosted services hub (Traefik, auth, media, monitoring, NUT UPS) |
| boron     | Desktop workstation | NVIDIA + PRIME, CUDA `franken-llama`, `llama-server`, Podman AI containers |
| nitrogen  | Headless AI & NVR server | Dual GPU (RTX 3080 Ti + AMD MI50), dual `franken-llama`, `llama-server`, Kokoro TTS, Frigate |
| helium    | Off-site backup server | Dell Wyse 5070, Restic backup target, monthly `autoUpgrade` |
| lithium   | Additional server | Zipline file sharing + Beszel client |
