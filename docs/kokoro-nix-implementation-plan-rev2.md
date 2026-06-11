# Kokoro TTS NixOS Module Implementation Plan (Rev 2)

This document supersedes the original implementation plan. It packages Kokoro TTS
as a **standalone Nix flake** at `~/devel/kokoro-flake`, modeled after the
`franken-llama` pattern already used in `server-nix`.

---

## 1. Goal & Architecture

- **Goal:** Replace the 43 GB OCI container `ghcr.io/remsky/kokoro-fastapi-rocm` on `nitrogen` with a native NixOS service that reuses the system's ROCm stack. Target: ~5–8 GB (shared with existing ROCm infra).
- **Flake Location:** `~/devel/kokoro-flake` (new Git repository).
- **Target Platform:** `nitrogen` — dual GPU: NVIDIA RTX 3080 Ti + AMD Instinct MI50 (gfx906).
- **ROCm Target:** `gfx906` via the existing `franken-llama` ROCm stack.

### Why a Standalone Flake?
1. **Isolation:** Keeps ~6 custom Python packages and their build logic out of `server-nix`.
2. **Reusability:** Any NixOS machine can add it as a flake input.
3. **Reproducibility:** `flake.lock` pins exact source revisions.
4. **Follows precedent:** Same pattern as `franken-llama` in the existing config.

---

## 2. Flake Structure

```
kokoro-flake/
├── flake.nix                  # Inputs, overlay, nixosModule, packages outputs
├── nixos-module.nix           # NixOS module: services.kokoro
├── wrapper.sh                 # Wrapper script for ExecStart (see §3D)
└── pkgs/
    ├── kokoro-fastapi/        # The FastAPI server application
    │   └── default.nix
    ├── espeakng-loader/       # Nix-native mock → points to pkgs.espeak-ng
    │   └── default.nix
    ├── phonemizer-fork/       # thewh1teagle/phonemizer-fork from PyPI
    │   └── default.nix
    ├── text2num/              # Missing dep for kokoro-fastapi
    │   └── default.nix
    └── en-core-web-sm/        # spaCy English model (wheel from GitHub)
        └── default.nix
```

---

## 3. Package Definitions

### A. `espeakng-loader` Mock

The upstream `espeakng-loader` (PyPI) ships precompiled `libespeak-ng.so` binaries
inside the wheel — incompatible with NixOS. We provide a trivial drop-in that
delegates to the system `espeak-ng` from nixpkgs.

```nix
{ lib, buildPythonPackage, espeak-ng, writeTextDir }:

let
  loaderSource = writeTextDir "espeakng_loader/__init__.py" ''
    import ctypes
    _lib = None

    def get_library_path():
        return "${espeak-ng}/lib/libespeak-ng.so"

    def get_data_path():
        return "${espeak-ng}/share/espeak-ng-data"

    def load_library():
        global _lib
        if _lib is None:
            _lib = ctypes.CDLL(get_library_path())
        return _lib
  '';
in
buildPythonPackage {
  pname = "espeakng-loader";
  version = "0.2.4";
  src = loaderSource;
  format = "setuptools";
  preBuild = ''
    cat <<EOF > setup.py
    from setuptools import setup
    setup(name='espeakng-loader', version='0.2.4', packages=['espeakng_loader'])
    EOF
  '';
}
```

### B. Other Missing Python Packages

| Package | Source | Notes |
|---------|--------|-------|
| `phonemizer-fork` | `thewh1teagle/phonemizer-fork` (PyPI or GitHub) | Fork of `phonemizer` with `espeakng-loader` integration and memory-leak fixes. Different import paths from upstream `phonemizer` in nixpkgs — cannot substitute. |
| `text2num` | PyPI | Word-to-number converter, required by kokoro-fastapi directly. |
| `en-core-web-sm` | GitHub release wheel | spaCy English model. Build from the pre-built wheel at `https://github.com/explosion/spacy-models/releases/download/en_core_web_sm-3.8.0/en_core_web_sm-3.8.0-py3-none-any.whl`. |

### Packages confirmed present in nixpkgs (no packaging needed)

`kokoro`, `misaki`, `torchWithRocm`, `fastapi`, `uvicorn`, `pydantic`,
`pydantic-settings`, `python-dotenv`, `sqlalchemy`, `numpy`, `scipy`,
`soundfile`, `regex`, `aiofiles`, `tqdm`, `requests`, `munch`, `tiktoken`,
`loguru`, `openai`, `pydub`, `matplotlib`, `mutagen`, `psutil`, `spacy`,
`inflect`, `av`, `click`, `spacy-curated-transformers`, `num2words`,
`transformers`.

### C. `kokoro-fastapi` Application

> [!WARNING]
> **No `[project.scripts]` entry point exists** in the upstream `pyproject.toml`.
> The container starts the app with:
> ```
> uvicorn api.src.main:app --host 0.0.0.0 --port 8880
> ```
> We cannot rely on `buildPythonApplication` producing a `bin/kokoro-fastapi`
> binary. We must either:
> 1. Patch the `pyproject.toml` to add a console script, or
> 2. **Use `buildPythonPackage`** (not Application) and invoke `uvicorn` via
>    a shell wrapper script (recommended — less patching, more transparent).

> [!IMPORTANT]
> **`PYTHONPATH` is critical.** The Dockerfile and `start-gpu.sh` both set
> `PYTHONPATH=$PROJECT_ROOT:$PROJECT_ROOT/api`. The `pyproject.toml` has
> `package-dir = { "" = "api/src" }`, meaning after `pip install`, the
> modules live at `api.src.main`, `api.src.core`, etc. This non-standard
> layout requires careful handling in the Nix build — either:
> - Install the package normally and use the installed module path, or
> - Set PYTHONPATH to include the source tree (fragile).
>
> **Recommendation:** Build as a normal Python package via `pyproject.toml`.
> After installation, the app module is `api.src.main:app`, which uvicorn can load.

```nix
{ lib, python3, fetchFromGitHub, espeak-ng, ffmpeg
, espeakng-loader, phonemizer-fork, text2num, en-core-web-sm
}:

let
  python = python3.override {
    packageOverrides = self: super: {
      torch = super.torchWithRocm;
    };
  };
in
python.pkgs.buildPythonPackage rec {
  pname = "kokoro-fastapi";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "remsky";
    repo = "Kokoro-FastAPI";
    rev = "v${version}";
    hash = "sha256-I2tf3sFt0GqphKNFJHXlQKDgeR34sCOSHMLMSNXNLqY=";
  };

  format = "pyproject";

  postPatch = ''
    # Slim down dependencies by removing non-English support
    substituteInPlace pyproject.toml \
      --replace-fail 'misaki[en,ja,ko,zh]==0.9.4' 'misaki[en]==0.9.4'
  '';

  propagatedBuildInputs = with python.pkgs; [
    # Core app deps
    fastapi uvicorn pydantic pydantic-settings python-dotenv sqlalchemy
    numpy scipy soundfile regex aiofiles tqdm requests munch tiktoken
    loguru openai pydub matplotlib mutagen psutil spacy inflect av click

    # Flake-provided packages
    espeakng-loader phonemizer-fork text2num en-core-web-sm

    # Upstream nixpkgs packages for kokoro/misaki ecosystem
    kokoro misaki
    spacy-curated-transformers
    num2words transformers
  ];

  nativeBuildInputs = with python.pkgs; [ setuptools wheel ];

  # Runtime native tools
  makeWrapperArgs = [
    "--prefix" "PATH" ":" "${lib.makeBinPath [ espeak-ng ffmpeg ]}"
  ];

  doCheck = false;

  # Include the web player and voice files in the output
  postInstall = ''
    # Copy web player (not installed by setuptools)
    cp -r $src/web $out/share/kokoro-fastapi/web

    # Voice files are installed into site-packages by setuptools
    # (they live under api/src/voices/ which is the package root)
  '';

  passthru = {
    inherit python;
  };

  meta = with lib; {
    description = "OpenAI-compatible FastAPI server for Kokoro TTS";
    homepage = "https://github.com/remsky/Kokoro-FastAPI";
    license = licenses.asl20;
    platforms = platforms.linux;
  };
}
```

### D. Wrapper Script (`wrapper.sh`)

Since the upstream has no console entry point, we need a small wrapper:

```bash
#!/usr/bin/env bash
# Wrapper for kokoro-fastapi — invoked by the systemd service.
# Uses the Python from the Nix-built package to ensure correct deps are on sys.path.

exec @python@/bin/python -m uvicorn api.src.main:app \
  --host "${HOST:-0.0.0.0}" \
  --port "${PORT:-8880}" \
  --log-level "${LOG_LEVEL:-info}"
```

This will be substituted during `postInstall` to inject the correct `@python@` path:

```nix
postInstall = ''
  mkdir -p $out/bin
  substitute ${../wrapper.sh} $out/bin/kokoro-fastapi \
    --replace-fail "@python@" "${python.withPackages (ps: self.propagatedBuildInputs)}"
  chmod +x $out/bin/kokoro-fastapi
'';
```

---

## 4. NixOS Module (`nixos-module.nix`)

### Key design decisions resolved from gap analysis:

#### 4.1 Entry Point
- ExecStart calls the wrapper script `$out/bin/kokoro-fastapi`, which runs `uvicorn api.src.main:app`.

#### 4.2 Model Download Strategy

> [!CAUTION]
> The app's `model_config.py` hardcodes the model path as **`v1_0/kokoro-v1_0.pth`**
> (relative to `MODEL_DIR`). The model download must create the correct subdirectory
> structure:
> ```
> /var/lib/kokoro/models/
> └── v1_0/
>     ├── kokoro-v1_0.pth   (~327 MB)
>     └── config.json        (~2.4 KB)
> ```
> The rev1 plan's download script put the model flat under `models/`, which would fail.

**Verified facts (tested on nitrogen 2026-06-11):**

| Source | URL | Status |
|--------|-----|--------|
| GitHub release (used by container) | `https://github.com/remsky/Kokoro-FastAPI/releases/download/v0.1.4/kokoro-v1_0.pth` | ✅ Works (302→200, 327 MB) |
| HuggingFace repo | `hexgrad/Kokoro-82M` has `kokoro-v1_0.pth` + `config.json` at root | ✅ Available (72 files, 363 MB total) |

The running container on nitrogen uses `download_model.py` which downloads from the
**GitHub release** (not HuggingFace). Journal confirms:
```
Jun 04 23:20:04 nitrogen kokoro[2002]: Downloading Kokoro v1.0 model files
Jun 04 23:20:04 nitrogen kokoro[2002]: Downloading model file...
Jun 04 23:20:08 nitrogen kokoro[2002]: Downloading config file...
Jun 04 23:20:08 nitrogen kokoro[2002]: ✓ Model files prepared in api/src/models/v1_0
```

**Option A: `wget` from GitHub releases (recommended)**
- Simple, no extra dependencies.
- Matches what the container actually does.
- Files go directly where we need them.

**Option B: `hf download` with `--local-dir`**
- Tested on nitrogen: `hf download hexgrad/Kokoro-82M config.json --local-dir /tmp/test-hf-kokoro`
  puts `config.json` directly in `/tmp/test-hf-kokoro/config.json`.
- Also creates metadata at `<local-dir>/.cache/huggingface/` (inside the target dir, not `~/.cache`).
- A minimal `refs/` entry is created in `~/.cache/huggingface/hub/models--hexgrad--Kokoro-82M/` but no blob data is duplicated there (as of `huggingface_hub` ≥0.23).
- Provides resumable downloads and version tracking.
- Requires `python3Packages.huggingface-hub` in the service path.
- **Caveat:** Files land at the root of `--local-dir`, preserving the HuggingFace repo structure. Since both `kokoro-v1_0.pth` and `config.json` are at the root of the HF repo, they'd land directly in the `--local-dir` — no `v1_0/` subdirectory is created automatically. The download service must set `--local-dir` to `$MODEL_DIR/v1_0` to match the expected layout.

**Recommendation:** Use **Option A** (`wget` from GitHub releases) for simplicity and to match the container behavior exactly. The `hf` tool is more appropriate for large model repos with many files and frequent updates, but Kokoro's model is a single ~327 MB file that rarely changes.

#### 4.3 Voices Directory
- Voice `.pt` files are installed into the Python package under `site-packages/voices/v1_0/`.
- Set `VOICES_DIR` to the installed location in the Nix store (read-only, which is fine for stock voices).
- The app also supports saving combined voices. If `allow_local_voice_saving` is needed, provide a writable overlay path. Default: disabled.

#### 4.4 ROCm / GPU Notes
- ROCm's HIP layer exposes GPUs via `torch.cuda.is_available()`. The `config.py` auto-detects this correctly — no need to set `DEVICE_TYPE` manually.
- `HSA_OVERRIDE_GFX_VERSION=9.0.6` is needed for the MI50 (gfx906).
- `TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1` — set in the container's docker-compose; include it for parity.
- `MIOPEN_FIND_MODE=2` — use the on-disk find DB (default in container). MIOpen cache directory should be persistent across reboots.

#### 4.5 MIOpen Kernel Cache
The ROCm Dockerfile installs MIOpen kernel database (.kdb) files and persists the
MIOpen cache via Docker volumes. For native NixOS:
- The MIOpen kdb files are part of `rocmPackages.miopen` in nixpkgs. No separate download is needed.
- Persist the runtime MIOpen cache at `/var/lib/kokoro/.config/miopen` and `/var/lib/kokoro/.cache/miopen` via the `HOME` env var pointing to `stateDir`.

#### 4.6 English-only Optimization (Japanese/Multilingual Support Disabled)
To keep the native NixOS service as slim and lightweight as possible:
- **Remove Multilingual Dependencies**: We explicitly patch `pyproject.toml` during `postPatch` to restrict the `misaki` package requirement to only English (`misaki[en]`).
- **Omit UniDic / Japanese packages**: The 526 MB Japanese `unidic` dictionary, `fugashi` (MeCab wrapper), `pyopenjtalk` (Japanese G2P), and language converters like `mojimoji` (Japanese) or `cn2an` (Chinese) are completely omitted. This reduces the closure size by ~1 GB, saves bandwidth, and avoids extra PyPI package builds.

#### 4.7 rocblas Library
The Dockerfile downloads a separate rocblas from Arch Linux to support older GFX
architectures (gfx906). On NixOS, `pkgs.rocmPackages.rocblas` already includes
gfx906 targets. We can verify with `ls $(nix-build '<nixpkgs>' -A rocmPackages.rocblas)/lib/rocblas/library/ | grep gfx906`.
If it does not, we can override `rocblas` with `gpuTargets = ["gfx906"]` (similar to
what the Frigate container config does in `nitrogen.nix`).

#### 4.8 Web Player
The container includes a `web/` directory that serves a browser-based TTS player at
`/web/`. The `config.py` has `enable_web_player = True` and `web_player_path = "web"`.
We need to include this in the package and set `WEB_PLAYER_PATH` to point to the
installed location.

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.services.kokoro;
  kokoro-fastapi = pkgs.kokoro-fastapi;
in
{
  options.services.kokoro = {
    enable = lib.mkEnableOption "Kokoro TTS service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8880;
      description = "Port for the Kokoro TTS API.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Host to bind to.";
    };

    defaultVoice = lib.mkOption {
      type = lib.types.str;
      default = "af_heart";
      description = "Default voice for TTS.";
    };

    useGpu = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable GPU acceleration.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/kokoro";
      description = "Directory for persistent state (models, cache, output).";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the firewall port for Kokoro.";
    };

    enableWebPlayer = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Serve the web-based TTS player UI at /web/.";
    };
  };

  config = lib.mkIf cfg.enable {
    # System user and group
    users.users.kokoro = {
      isSystemUser = true;
      group = "kokoro";
      extraGroups = [ "render" "video" ];
      home = cfg.stateDir;
      createHome = true;
    };
    users.groups.kokoro = {};

    # === Model Download (oneshot, before main service) ===
    systemd.services.kokoro-model-download = {
      description = "Download Kokoro TTS model weights";
      wantedBy = [ "kokoro.service" ];
      before = [ "kokoro.service" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      path = [ pkgs.wget pkgs.coreutils ];

      serviceConfig = {
        Type = "oneshot";
        User = "kokoro";
        Group = "kokoro";
        StateDirectory = "kokoro";
      };

      # Model must be at v1_0/kokoro-v1_0.pth relative to MODEL_DIR.
      # Uses wget from GitHub releases — same source the container's
      # download_model.py uses (verified working on nitrogen 2026-06-11,
      # 302→200 redirect, ~327 MB).
      script = ''
        MODEL_BASE="${cfg.stateDir}/models/v1_0"
        mkdir -p "$MODEL_BASE"

        if [ ! -f "$MODEL_BASE/kokoro-v1_0.pth" ]; then
          echo "Downloading kokoro-v1_0.pth (~327 MB)..."
          wget -q -c -O "$MODEL_BASE/kokoro-v1_0.pth" \
            https://github.com/remsky/Kokoro-FastAPI/releases/download/v0.1.4/kokoro-v1_0.pth
        fi

        if [ ! -f "$MODEL_BASE/config.json" ]; then
          echo "Downloading config.json..."
          wget -q -c -O "$MODEL_BASE/config.json" \
            https://github.com/remsky/Kokoro-FastAPI/releases/download/v0.1.4/config.json
        fi

        # Verify files exist and are non-empty
        for f in kokoro-v1_0.pth config.json; do
          if [ ! -s "$MODEL_BASE/$f" ]; then
            echo "ERROR: $f is missing or empty" >&2
            exit 1
          fi
        done

        echo "Model files ready at $MODEL_BASE"
      '';
    };

    # === Main Kokoro TTS Service ===
    systemd.services.kokoro = {
      description = "Kokoro TTS FastAPI Server";
      after = [ "network.target" "kokoro-model-download.service" ];
      requires = [ "kokoro-model-download.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        # Application config (pydantic-settings reads these as env vars)
        HOST = cfg.host;
        PORT = toString cfg.port;
        DEFAULT_VOICE = cfg.defaultVoice;
        USE_GPU = if cfg.useGpu then "true" else "false";

        # Paths — absolute paths override the os.path.join logic in paths.py
        MODEL_DIR = "${cfg.stateDir}/models";
        VOICES_DIR = "${kokoro-fastapi}/${kokoro-fastapi.python.sitePackages}/voices/v1_0";
        OUTPUT_DIR = "${cfg.stateDir}/output";
        TEMP_FILE_DIR = "${cfg.stateDir}/temp";
        WEB_PLAYER_PATH = "${kokoro-fastapi}/share/kokoro-fastapi/web";
        ENABLE_WEB_PLAYER = if cfg.enableWebPlayer then "true" else "false";

        # ROCm / GPU tuning
        HSA_OVERRIDE_GFX_VERSION = "9.0.6";  # MI50 = gfx906
        TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL = "1";
        MIOPEN_FIND_MODE = "2";  # Reuse on-disk find DB

        # MIOpen cache location (HOME-relative)
        HOME = cfg.stateDir;

        # espeak paths
        PHONEMIZER_ESPEAK_PATH = "${pkgs.espeak-ng}/bin";
        PHONEMIZER_ESPEAK_DATA = "${pkgs.espeak-ng}/share/espeak-ng-data";
        ESPEAK_DATA_PATH = "${pkgs.espeak-ng}/share/espeak-ng-data";
      };

      serviceConfig = {
        Type = "simple";
        User = "kokoro";
        Group = "kokoro";
        ExecStart = "${kokoro-fastapi}/bin/kokoro-fastapi";
        Restart = "on-failure";
        RestartSec = "5s";

        # GPU access
        SupplementaryGroups = [ "render" "video" ];

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [ cfg.stateDir ];
        StateDirectory = "kokoro";
        StateDirectoryMode = "0750";
      };
    };

    # Ensure writable directories exist
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir}/models 0750 kokoro kokoro -"
      "d ${cfg.stateDir}/output 0750 kokoro kokoro -"
      "d ${cfg.stateDir}/temp 0750 kokoro kokoro -"
      "d ${cfg.stateDir}/.config/miopen 0750 kokoro kokoro -"
      "d ${cfg.stateDir}/.cache/miopen 0750 kokoro kokoro -"
    ];

    # Firewall
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
```

---

## 5. Integration into `server-nix`

### A. `flake.nix` Changes

```nix
# 1. Add input (local path for development; change to GitHub URL for production)
kokoro-flake = {
  url = "github:bowmanjd/kokoro-flake";   # or "git+file:///home/jbowman/devel/kokoro-flake"
  inputs.nixpkgs.follows = "nixpkgs";
};

# 2. Add overlay to baseOverlays
baseOverlays = [
  overlay-stable
  overlay-tp
  overlay-staging
  overlay-master
  inputs.kokoro-flake.overlays.default
];

# 3. Add NixOS module to commonModules
commonModules = [
  inputs.disko.nixosModules.disko
  ./nixos
  inputs.home-manager.nixosModules.home-manager
  inputs.catppuccin.nixosModules.catppuccin
  inputs.franken-llama.nixosModules.default
  inputs.kokoro-flake.nixosModules.default
];
```

### B. `machines/nitrogen.nix` Changes

```diff
-        kokoro = {
-          image = "ghcr.io/remsky/kokoro-fastapi-rocm:latest";
-          autoStart = true;
-          ports = ["0.0.0.0:8880:8880"];
-          extraOptions = [
-            "--device=/dev/kfd"
-            "--device=/dev/dri"
-            "--group-add=303" # render group for GPU
-            "--group-add=26"  # video group for GPU
-          ];
-        };

+  # Native Kokoro TTS (replaces ghcr.io/remsky/kokoro-fastapi-rocm container)
+  services.kokoro = {
+    enable = true;
+    port = 8880;
+    useGpu = true;
+    openFirewall = true;
+  };
```

---

## 6. Estimated Size Comparison

| Component | Container | Native (shared) |
|-----------|-----------|-----------------|
| ROCm stack | ~15 GB (bundled) | 0 GB (shared with franken-llama) |
| PyTorch ROCm | ~8 GB (bundled) | ~4 GB (nixpkgs, shared) |
| Python deps | ~5 GB | ~500 MB |
| Models | ~500 MB | ~500 MB |
| FastAPI app | ~100 MB | ~50 MB |
| Container overhead | ~14 GB | 0 |
| **Total** | **~43 GB** | **~5 GB** |

---

## 7. Validation Checklist

- [ ] Each custom Python package builds individually (`nix build .#espeakng-loader`, etc.)
- [ ] `kokoro-fastapi` package builds (on a machine without GPU)
- [ ] `kokoro-model-download` service downloads models to correct path (`v1_0/kokoro-v1_0.pth`)
- [ ] `kokoro` service starts and binds to port 8880
- [ ] ROCm GPU is detected (`torch.cuda.is_available()` returns True)
- [ ] `/v1/audio/speech` endpoint returns audio
- [ ] `/health` endpoint returns `{"status": "healthy"}`
- [ ] Web player accessible at `http://<host>:8880/web/`
- [ ] Audio quality matches container version
- [ ] MIOpen cache persists across service restarts (check `~kokoro/.cache/miopen/`)
- [ ] Memory usage is reasonable
- [ ] Service restarts cleanly after failure
- [ ] rocblas has gfx906 kernels (check library directory)

---

## 8. Rollback Plan

Keep the container definition commented out in `nitrogen.nix` until the native
service is validated. Revert by uncommenting the container block and setting
`services.kokoro.enable = false`.

---

## 9. Risk Registry

| Risk | Impact | Mitigation |
|------|--------|------------|
| nixpkgs `kokoro`/`misaki` version mismatch with FastAPI's pinned `0.9.4` | App crash or wrong output | Pin versions via overlay if needed; verify during build |
| `torchWithRocm` doesn't support gfx906 | No GPU acceleration | Falls back to CPU; verify with `torch.cuda.is_available()` in a test script |
| `phonemizer-fork` has diverged from upstream `phonemizer` | Import errors | Package fork separately; do not substitute nixpkgs `phonemizer` |
| `paths.py` calls `os.makedirs` on read-only Nix store paths | Crash on voice listing | Voices dir is absolute, so `os.path.join` returns the absolute path; makedirs on existing dir is a no-op. Test carefully. |
| MIOpen kernel search causes 5–60s latency on first inference | Slow first request | Accept for now; optionally add a warmup oneshot service later |
| UniDic dictionary not found at runtime | Japanese TTS fails | Verify `python3Packages.unidic` in nixpkgs includes the dict data |
| `en-core-web-sm` version incompatible with nixpkgs `spacy` | spaCy load failure | Match wheel version to nixpkgs spaCy version |

---

## 10. Action Plan (Sequenced)

### Phase 1: Scaffold the Flake
1. `mkdir ~/devel/kokoro-flake && cd ~/devel/kokoro-flake && git init`
2. Create `flake.nix` with inputs, overlay, and nixosModules outputs.
3. Create directory structure under `pkgs/`.

### Phase 2: Package Dependencies
4. Build `espeakng-loader` mock — simplest, no network deps.
5. Build `text2num`, `cn2an`, `mojimoji` from PyPI (compute hashes).
6. Build `phonemizer-fork` from PyPI or GitHub.
7. Build `en-core-web-sm` from wheel.

### Phase 3: Package kokoro-fastapi
8. `nix-prefetch-url --unpack` for the GitHub archive hash.
9. Write the `buildPythonPackage` derivation.
10. Write the wrapper script.
11. Test: `nix build .#kokoro-fastapi`.

### Phase 4: Write the NixOS Module
12. Create `nixos-module.nix` with the full module definition above.
13. Verify rocblas gfx906 support on nitrogen.

### Phase 5: Integrate into server-nix
14. Add flake input + overlay + module to `server-nix/flake.nix`.
15. Update `machines/nitrogen.nix`.
16. Build: `nh os switch ./` on nitrogen.
17. Run validation checklist.

### Phase 6: Cleanup
18. Remove (or comment out) the container definition.
19. `podman rmi ghcr.io/remsky/kokoro-fastapi-rocm:latest` to reclaim 43 GB.

---

## 11. References

- Kokoro-FastAPI repo: https://github.com/remsky/Kokoro-FastAPI
- Kokoro model: https://huggingface.co/hexgrad/Kokoro-82M
- nixpkgs `python3Packages.kokoro`: `0-unstable-2025-06-16`
- nixpkgs `python3Packages.misaki`: `0-unstable-2025-06-16`
- nixpkgs `python3Packages.torchWithRocm`
- `phonemizer-fork`: https://github.com/thewh1teagle/phonemizer-fork
- `espeakng-loader`: https://github.com/thewh1teagle/espeakng-loader
- franken-llama pattern: `services.franken-llama` in `machines/nitrogen.nix`
- Container Dockerfile: `~/src/Kokoro-FastAPI/docker/rocm/Dockerfile`
- Container entrypoint: `uvicorn api.src.main:app --host 0.0.0.0 --port 8880`
