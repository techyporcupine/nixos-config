# Kokoro TTS NixOS Module Implementation Plan

## Goal

Replace the 43 GB `ghcr.io/remsky/kokoro-fastapi-rocm` container on `nitrogen` with a native NixOS module that reuses the system's ROCm stack. Target size: ~5-8 GB (shared with existing ROCm infrastructure).

## Context

**Target machine:** `nitrogen` (NixOS server)
- Dual GPU: NVIDIA RTX 3080 Ti + AMD Instinct MI50 (gfx906)
- Existing ROCm stack via `franken-llama` flake with `acceleration = "dual"`
- ROCm target: `gfx906`

**Current state:** Container defined in `machines/nitrogen.nix`:
```nix
kokoro = {
  image = "ghcr.io/remsky/kokoro-fastapi-rocm:latest";
  autoStart = true;
  ports = ["0.0.0.0:8880:8880"];
  extraOptions = [
    "--device=/dev/kfd"
    "--device=/dev/dri"
    "--group-add=303"  # render
    "--group-add=26"   # video
  ];
};
```

## Key Discovery: nixpkgs Already Has Most Dependencies

These packages exist in nixpkgs (as of 2025-06):
- `python3Packages.kokoro` - Core TTS model (0-unstable-2025-06-16)
- `python3Packages.misaki` - G2P/phonemization engine
- `python3Packages.torchWithRocm` - PyTorch 2.12.0 with ROCm support
- `python3Packages.fastapi`, `uvicorn`, `pydantic`, etc.
- `python3Packages.huggingface-hub` - HuggingFace CLI for model downloads

The server already has `huggingface-hub` installed (`hf` CLI), which can download models.

## Implementation Tasks

### Phase 1: Package Kokoro-FastAPI

Create `nixos/pkgs/kokoro-fastapi/default.nix`:

```nix
{ lib
, python3
, fetchFromGitHub
, espeak-ng
, ffmpeg
}:

let
  python = python3.override {
    packageOverrides = self: super: {
      # Use ROCm-enabled PyTorch
      torch = super.torchWithRocm;
    };
  };
in
python.pkgs.buildPythonApplication rec {
  pname = "kokoro-fastapi";
  version = "0.5.0";  # Match latest release

  src = fetchFromGitHub {
    owner = "remsky";
    repo = "Kokoro-FastAPI";
    rev = "v${version}";
    hash = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";  # TODO: compute
  };

  format = "pyproject";

  propagatedBuildInputs = with python.pkgs; [
    # Core TTS
    kokoro
    misaki

    # Web framework
    fastapi
    uvicorn
    pydantic
    pydantic-settings

    # Audio processing
    soundfile
    pydub
    av

    # NLP
    spacy
    inflect
    phonemizer

    # Utilities
    aiofiles
    loguru
    munch
    tiktoken
    requests
    tqdm
    psutil
    sqlalchemy
    python-dotenv
    click
    regex
    numpy
    scipy
    matplotlib
    mutagen
  ];

  nativeBuildInputs = with python.pkgs; [
    setuptools
    wheel
  ];

  # Runtime dependencies
  makeWrapperArgs = [
    "--prefix" "PATH" ":" "${lib.makeBinPath [ espeak-ng ffmpeg ]}"
  ];

  # Skip tests (require GPU)
  doCheck = false;

  meta = with lib; {
    description = "OpenAI-compatible FastAPI server for Kokoro TTS";
    homepage = "https://github.com/remsky/Kokoro-FastAPI";
    license = licenses.asl20;
    platforms = platforms.linux;
  };
}
```

**Potential issues to investigate:**
1. The repo may not have a proper `pyproject.toml` for installation - may need to patch or use `installPhase`
2. `phonemizer-fork` vs `phonemizer` in nixpkgs
3. `espeakng-loader` package availability
4. `text2num` package availability
5. spaCy model `en-core-web-sm` download/packaging

### Phase 2: Create NixOS Module

Create `nixos/server/kokoro.nix`:

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.tp.server.kokoro;
  kokoro-fastapi = pkgs.callPackage ../pkgs/kokoro-fastapi {};
in
{
  options.tp.server.kokoro = {
    enable = lib.mkEnableOption "Kokoro TTS server";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8880;
      description = "Port for the Kokoro TTS API";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Host to bind to";
    };

    defaultVoice = lib.mkOption {
      type = lib.types.str;
      default = "af_heart";
      description = "Default voice for TTS";
    };

    useGpu = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable GPU acceleration (ROCm)";
    };

    modelDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/kokoro/models";
      description = "Directory for TTS models";
    };

    voicesDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/kokoro/voices";
      description = "Directory for voice files";
    };

    outputDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/kokoro/output";
      description = "Directory for generated audio output";
    };

    rocmTarget = lib.mkOption {
      type = lib.types.str;
      default = "gfx906";
      description = "ROCm GPU target architecture";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall port for Kokoro";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create system user
    users.users.kokoro = {
      isSystemUser = true;
      group = "kokoro";
      extraGroups = [ "render" "video" ];  # GPU access
      home = "/var/lib/kokoro";
      createHome = true;
    };
    users.groups.kokoro = {};

    # Systemd service
    systemd.services.kokoro = {
      description = "Kokoro TTS Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        HOST = cfg.host;
        PORT = toString cfg.port;
        DEFAULT_VOICE = cfg.defaultVoice;
        USE_GPU = if cfg.useGpu then "true" else "false";
        MODEL_DIR = cfg.modelDir;
        VOICES_DIR = cfg.voicesDir;
        OUTPUT_DIR = cfg.outputDir;
        HSA_OVERRIDE_GFX_VERSION = "9.0.6";  # For MI50
        ROCM_PATH = "${pkgs.rocmPackages.clr}";
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
        ReadWritePaths = [
          cfg.modelDir
          cfg.voicesDir
          cfg.outputDir
        ];

        # State directories
        StateDirectory = "kokoro";
        StateDirectoryMode = "0750";
      };
    };

    # Ensure directories exist
    systemd.tmpfiles.rules = [
      "d ${cfg.modelDir} 0750 kokoro kokoro -"
      "d ${cfg.voicesDir} 0750 kokoro kokoro -"
      "d ${cfg.outputDir} 0750 kokoro kokoro -"
    ];

    # Firewall
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
```

### Phase 3: Model Download

The Kokoro models need to be downloaded from HuggingFace. The server already has `huggingface-hub` installed (provides `hf` CLI).

**Option A: Nix-managed (reproducible, cached in store)**
```nix
kokoroModels = pkgs.fetchurl {
  url = "https://huggingface.co/hexgrad/Kokoro-82M/resolve/main/kokoro-v0_19.pth";
  hash = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";  # TODO: compute
};

kokoroVoices = pkgs.fetchzip {
  url = "https://github.com/remsky/Kokoro-FastAPI/releases/download/v0.5.0/voices.zip";
  hash = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";  # TODO: compute
};
```

**Option B: Runtime download via hf CLI (simpler, allows updates)**

Create a oneshot service that runs before the main service:
```nix
systemd.services.kokoro-models = {
  description = "Download Kokoro TTS models";
  before = [ "kokoro.service" ];
  wantedBy = [ "kokoro.service" ];
  
  path = [ pkgs.python3Packages.huggingface-hub ];
  
  serviceConfig = {
    Type = "oneshot";
    User = "kokoro";
    Group = "kokoro";
    StateDirectory = "kokoro";
  };
  
  script = ''
    cd /var/lib/kokoro
    
    # Download model if not present
    if [[ ! -f models/kokoro-v0_19.pth ]]; then
      hf download hexgrad/Kokoro-82M kokoro-v0_19.pth --local-dir models
    fi
    
    # Download voices if not present  
    if [[ ! -d voices/v1_0 ]]; then
      hf download hexgrad/Kokoro-82M voices --local-dir voices
    fi
  '';
};
```

**Recommendation:** Use Option B for flexibility - models can be updated without rebuilding the system, and `hf` handles caching/resumption automatically.

### Phase 4: Integration

Update `machines/nitrogen.nix`:

```nix
# Remove the container definition
# virtualisation.oci-containers.containers.kokoro = { ... };

# Add the native service
tp.server.kokoro = {
  enable = true;
  port = 8880;
  useGpu = true;
  rocmTarget = "gfx906";
  openFirewall = true;
};
```

Update `nixos/default.nix` to import the new module:
```nix
imports = [
  ./server/kokoro.nix
  # ... other imports
];
```

## Open Questions to Investigate

1. **Kokoro-FastAPI entry point**: What's the actual command to start the server?
   - Check if it's `uvicorn api.main:app` or a custom script
   - May need to wrap with proper PYTHONPATH

2. **Missing Python packages**: Check nixpkgs for:
   - `phonemizer-fork` (may need `phonemizer` + patch)
   - `espeakng-loader` (may not be needed if espeak-ng is in PATH)
   - `text2num`
   - `en-core-web-sm` spaCy model

3. **ROCm compatibility**: Verify `torchWithRocm` works with:
   - The specific Kokoro model architecture
   - gfx906 target (MI50)

4. **Model paths**: The FastAPI server expects models in specific locations. May need:
   - Symlinks from the Nix store
   - Environment variable overrides
   - Wrapper script to set up paths

## Estimated Size Comparison

| Component | Container | Native (shared) |
|-----------|-----------|-----------------|
| ROCm stack | ~15 GB (bundled) | 0 (shared with franken-llama) |
| PyTorch ROCm | ~8 GB (bundled) | ~4 GB (nixpkgs) |
| Python deps | ~5 GB | ~500 MB |
| Models | ~500 MB | ~500 MB |
| FastAPI app | ~100 MB | ~50 MB |
| Container overhead | ~14 GB | 0 |
| **Total** | **~43 GB** | **~5 GB** |

## Validation Checklist

- [ ] Package builds without GPU
- [ ] Service starts and binds to port
- [ ] Models download/load correctly
- [ ] ROCm GPU is detected
- [ ] `/v1/audio/speech` endpoint works
- [ ] Audio quality matches container version
- [ ] Memory usage is reasonable
- [ ] Service restarts cleanly

## Rollback Plan

Keep the container definition commented out in `nitrogen.nix` until the native service is validated. Can quickly revert by uncommenting and disabling the native service.

## References

- Kokoro-FastAPI repo: https://github.com/remsky/Kokoro-FastAPI
- Kokoro model: https://huggingface.co/hexgrad/Kokoro-82M
- nixpkgs kokoro: `python3Packages.kokoro`
- nixpkgs torchWithRocm: `python3Packages.torchWithRocm`
- huggingface-hub CLI: `python3Packages.huggingface-hub` (provides `hf` command)
- Existing franken-llama config: `services.franken-llama` in `machines/nitrogen.nix`
