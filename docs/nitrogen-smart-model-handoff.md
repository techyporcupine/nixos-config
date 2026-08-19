# nitrogen "smart" model: OOM fix, context tuning, perf resolution

Read this in full before touching
`nixos/server/llama-server/nitrogen-models.ini` or
`nixos/server/llama-server/default.nix`.

## Status

Resolved and validated. `smart` runs with explicit static allocations (`fit = off`, `ngl = 99`, `c = 98304`, `ts = 28,37`) yielding ~23.8 tok/s generation throughput with 100% GPU offload and no host memory spillover.

## The setup

`nitrogen` is a home server running an NVIDIA RTX 3080 Ti (`CUDA0`, 12288 MiB) and an AMD Instinct MI50 (`ROCm0`, gfx906, 32752 MiB, no matrix cores) side by side. `llama-server`'s built-in router mode manages model presets from `nixos/server/llama-server/nitrogen-models.ini`, deployed via `nixos/server/llama-server/default.nix` as a `systemd --user` service.

Two models remain permanently resident (`sleep-idle-seconds = -1`):
- `fast`: Qwen3.5-9B, Q4_K_M, vision-capable (mmproj on CPU via `no-mmproj-offload = true`). Fixed config: `dev = ROCM0`, `fit = off`, `c = 131072`.
- `smart`: Qwen3.8-27B, Q5_K_M. Spans both devices: `dev = CUDA0,ROCM0`. Uses `--spec-type draft-mtp` (MTP/NextN head on ROCm0).

`smart` architecture (GGUF arch string `qwen35`) is a hybrid Mamba/attention model:
- Total blocks: 65 (64 transformer/SSM blocks + 1 MTP head at block 64).
- `full_attention_interval = 4`: only 1 in 4 layers (16 layers total) are self-attention with KV cache.
- The remaining 48 layers are SSM recurrent blocks with constant O(1) state per sequence, scaling with `n_seq_max`, not context length.

## Problem 1 (SOLVED): smart OOM'd on load

Root causes:
1. `fitt` (`--fit-target`) is the free margin `--fit` leaves per device. Dynamic fit did not budget for MTP draft context (~2.3 GiB on ROCm0).
2. `fast` mmproj projector was defaulting to CUDA0 until `no-mmproj-offload = true` pinned it to CPU.
3. Both models loaded concurrently with `load-on-startup = true`, competing for dynamic free VRAM.

Fixes applied:
- Added `tp.server.llama-server.warmup` service (`nixos/server/llama-server/llama-warmup.sh`) for sequential startup.
- `no-mmproj-offload = true` on `fast`.

## Problem 2 & 3 (SOLVED): auto-fit inefficiencies and CPU fallback regression

When `c = 131072` was previously tested with `--fit`, generation throughput dropped to ~2.4 tok/s with 0-12% GPU utilization.

Root cause confirmed:
- Dynamic `--fit` overflowed physical VRAM on CUDA0 and placed buffers/layers into host CPU RAM (`CPU*` buffers or GTT host memory).
- GPU execution stalled on PCIe memory transfers during recurrent state and KV cache access on every token.
- `--fit` also under-utilized CUDA0 when unpinned (leaving ~10 GB idle across both cards).

Resolution:
- Discard dynamic `--fit` on `smart` entirely (`fit = off`, removed `fitt = 2048`).
- Set `ngl = 99` so any memory shortfall fails loudly at startup with an explicit out-of-memory error rather than silently degrading performance to CPU RAM.
- Explicitly set context size `c` and layer split `ts`.

## Context and Layer Split Benchmarks

1. `c = 65536`, `ts = 28,37` (29 layers on CUDA0, 37 layers on ROCm0):
- CUDA0: 7,613.59 MiB weights + 952.00 MiB KV + 1,097.25 MiB RS + 832.33 MiB compute = 10,495.17 MiB used (~1,416 MiB free).
- ROCm0: 10,457.56 MiB weights + 1,224.00 MiB KV + 1,296.75 MiB RS + 832.33 MiB compute + 256.00 MiB MTP KV + 528.06 MiB MTP compute = 14,594.70 MiB used.
- Throughput: 20.6 - 22.3 tok/s.

2. `c = 98304`, `ts = 28,37` (Current Active Configuration):
- CUDA0: 7,613.59 MiB weights + 1,428.00 MiB KV + 1,097.25 MiB RS + 1,088.33 MiB compute = 11,227.17 MiB used (~684 MiB free margin).
- ROCm0: 10,457.56 MiB weights + 1,836.00 MiB KV + 1,296.75 MiB RS + 1,088.33 MiB compute + 384.00 MiB MTP KV + 656.06 MiB MTP compute = 15,718.70 MiB used.
- Throughput: 21.6 - 23.8 tok/s on text; up to 32.8 tok/s on code tasks.

3. `c = 131072`, `ts = 28,37`:
- Failed fast with `cudaMalloc failed: out of memory` on CUDA0 (requested 11,959 MiB vs 11,911 MiB usable).

4. `c = 131072`, `ts = 26,39` (27 layers on CUDA0, 39 layers on ROCm0):
- Moving layer 27 (attention layer) to ROCm0 freed ~557 MiB on CUDA0.
- CUDA0: 7,094.56 MiB weights + 1,632.00 MiB KV + 1,047.38 MiB RS + 1,344.33 MiB compute = 11,118.27 MiB used (~793 MiB free margin).
- ROCm0: 10,976.59 MiB weights + 2,720.00 MiB KV + 1,346.62 MiB RS + 1,344.33 MiB compute + 512.00 MiB MTP KV + 784.06 MiB MTP compute = 17,683.60 MiB used.
- Throughput: 19.5 - 19.7 tok/s.

## Speculative Decoding Tuning (Coding Task Benchmarks)

Tested on identical Python implementation task (250 tokens generated per test):

1. Non-speculative (`spec-type = none`):
- Throughput: 26.00 tok/s (eval time: 9,577 ms)
- Acceptance: N/A

2. MTP default (`spec-draft-n-max = 3`, `min-p = 0.0`):
- Throughput: 30.35 tok/s (eval time: 8,205 ms)
- Acceptance: 78.38% (mean length: 3.35)

3. MTP with confidence cutoff (`spec-draft-p-min = 0.75`, `n-max = 3`):
- Throughput: 29.29 tok/s (eval time: 8,501 ms)
- Acceptance: 87.36% (mean length: 2.95)

4. MTP with 2 draft tokens (`spec-draft-n-max = 2`, `min-p = 0.05`):
- Throughput: 32.42 tok/s (eval time: 7,681 ms)
- Acceptance: 80.53% (mean length: 2.61)

5. MTP with 1 draft token (`spec-draft-n-max = 1`, `min-p = 0.05`) (Selected Configuration):
- Throughput: 32.81 tok/s (eval time: 7,590 ms)
- Acceptance: 94.53% (mean length: 1.95)

## Current Configuration for `[smart]` in `nitrogen-models.ini`

```ini
[smart]
hf = unsloth/Qwen3.8-27B-GGUF:Q5_K_M
dev = CUDA0,ROCM0
no-mmproj = true
sleep-idle-seconds = -1
reasoning = off
spec-type = draft-mtp
spec-draft-n-max = 1
ctk = q8_0
ctv = q8_0
ub = 2048
fit = off
ngl = 99
c = 98304
ts = 28,37
temp = 0.6
top-k = 20
min-p = 0.05
top-p = 0.95
presence-penalty = 0.0
repeat-penalty = 1.0
```
