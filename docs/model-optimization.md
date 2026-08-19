# Model Optimization Strategy & Benchmarking Guide

Comprehensive guide, cost model, decision rubric, and benchmarking protocol for optimizing the `smart` model (Qwen 3.8 27B) on `nitrogen`.

## Hardware Context & Baseline Reality

### Hardware Architecture
- `CUDA0`: NVIDIA RTX 3080 Ti (12,288 MiB total, ~11,911 MiB usable, ~912 GB/s theoretical memory bandwidth, ~700 GB/s effective).
- `ROCm0`: AMD Instinct MI50 gfx906 (32,752 MiB total, ~24,300 MiB usable after `fast`, 1,024 GB/s theoretical HBM2 bandwidth, ~560 GB/s effective, no matrix cores).
- `fast`: Qwen3.5-9B, permanently resident on `ROCm0` (`c = 131072`, `dev = ROCM0`, `no-mmproj-offload = true`, ~7.9 GiB VRAM). Do not alter.
- `smart`: Qwen3.8-27B hybrid Mamba/attention (65 total blocks: 64 transformer/SSM blocks + 1 MTP draft head at `blk.64`).
  - 16 self-attention layers with KV cache (`full_attention_interval = 4`: layers 3, 7, 11, 15, 19, 23, 27, 31, 35, 39, 43, 47, 51, 55, 59, 63).
  - 48 SSM recurrent layers with fixed O(1) state per sequence (~50 MiB/layer), invariant to context length.

### Current Validated Baseline (Commit `4b114f3`)
- Configuration: `hf = unsloth/Qwen3.8-27B-GGUF:Q5_K_M`, `c = 98304`, `ts = 28,37`, `spec-type = draft-mtp`, `spec-draft-n-max = 1`, `min-p = 0.05`, `top-k = 20`, `top-p = 0.95`, `fit = off`, `ngl = 99`.
- Generation throughput: ~32.8–33.3 tok/s (eval time: ~7,580 ms / 250 tokens).
- Prompt evaluation: ~105 tok/s.
- Draft acceptance: 94.5%–96.0% (mean length: 1.95 tokens/cycle).
- Performance ceiling: At Q5_K_M with dual-GPU split, theoretical bandwidth limit is ~35 tok/s. Parametric fine-tuning cannot exceed this ceiling.

## Core Rules & Invariants

- Target configuration file: [`nixos/server/llama-server/nitrogen-models.ini`](file:///home/bowmanjd/devel/caleb-nix/nixos/server/llama-server/nitrogen-models.ini)
- No comments in the INI file (record rationale in Git commit messages only).
- Hard fail-fast invariants: `fit = off` and `ngl = 99` always. Never enable `--fit` on `smart` (causes silent fallback to host CPU RAM at 2.4 tok/s).
- KV Cache Precision: `ctk = q8_0, ctv = q8_0` always. Do NOT use `ctv = q4_0` (gfx906 lacks 4-bit matrix cores; software 4-bit dequantization slows generation from 33 tok/s to 8.5 tok/s).
- Minimum safety headroom: Keep ≥700 MiB free margin on `CUDA0` across restarts to prevent memory fragmentation failures.
- Noise floor rule: Any configuration change delivering under 1% throughput gain is measurement noise and should not be deployed.

## Sizing Math & Layer Placement Exchange Rate

### Cost Model & Memory Formulas
- Full Pass Time: `T ≈ 34 ms` (non-speculative pass = 26.0 tok/s).
- Draft Step Time: `d ≈ 25 ms` (1 MTP draft token on ROCm0).
- Cycle Time: `T + d ≈ 59 ms` per 2-token batch → 33.3 tok/s at 95% acceptance.
- CUDA0 Usable Budget: 11,911 MiB.
- CUDA0 Memory Consumption:
  `CUDA0_Used = Weights + KV_Cache + SSM_State + Compute_Buffer`
  - `Weights`: ~285 MiB per layer (measured ~7,614 MiB for 29 layers on Q5_K_M).
  - `KV_Cache`: `(Attention_Layers_on_CUDA0) × (c) × (2,176 Bytes/token)`. At 7 attention layers and `c = 98304`, KV = 1,428 MiB.
  - `SSM_State`: `(SSM_Layers_on_CUDA0) × 49.88 MiB`. For 22 SSM layers = 1,097 MiB.
  - `Compute_Buffer`: ~1,088 MiB at `ub = 2048`.

### The Layer Shift vs. Context Exchange Rate
Moving 1 layer from ROCm0 to CUDA0 saves only `285 MiB × (1/560 − 1/700 GB/s) = 0.106 ms` (~0.18% of a 59 ms cycle).
However, 1 layer takes ~335 MiB on CUDA0, which consumes the equivalent of ~23,000 tokens of context.

- Trading context for CUDA0 layers is an anti-pattern (e.g. dropping from 98k to 49k context to gain 3 layers yields only +0.5% speed).
- The correct optimization trade is the opposite: shifting 1–2 layers to ROCm0 (e.g. `ts = 26,39`) drops an attention layer from CUDA0, freeing enough VRAM to reach `c = 131072` with >780 MiB safety headroom at virtually zero speed loss (-0.5%).

## Optimization Decision Matrix & Ranked Levers

1. Model Quantization (`Q5_K_M` → `UD-Q4_K_XL`):
   - Impact: +17% to +25% generation speed (~40+ tok/s), frees ~3.1 GB total VRAM.
   - Mechanism: Reduces memory traffic per token from 18.6 GB to ~15.5 GB; Q4_K has better optimized kernels on gfx906.
   - Confidence: High.

2. Prompt Cache & Prefix Reuse:
   - Impact: 10x–100x reduction in perceived latency on multi-turn coding sessions.
   - Mechanism: Reuses KV cache for stable prompt prefixes; eliminates 3–5 minute prefill stalls at 20k–30k context.
   - Confidence: High.

3. Speculative Draft Max Setting (`spec-draft-n-max = 1`):
   - Impact: +26% speedup over non-speculative baseline (already verified).
   - Mechanism: Eliminates cross-GPU synchronization penalty of 3rd draft token.
   - Confidence: High.

4. GPU-Native Sampler Chain (`top-k = 20, top-p = 0.95, min-p = 0.05`):
   - Impact: Verified optimal alignment with MTP draft head (95%+ acceptance).
   - Confidence: High.

5. Layer Shuffling (`ts = ±1 layer`):
   - Impact: ±0.18% (negligible). Use only to satisfy VRAM headroom constraints for target context size.
   - Confidence: High.

## Testing Protocol for New Quants & Changes

### Step 1: Diagnostic Verbosity Load
Add temporary `verbosity = 5` to `[*]` in `nitrogen-models.ini` to verify buffer allocations:
```bash
git add nixos/server/llama-server/nitrogen-models.ini && git commit -m "diag: inspect quant buffer sizes" && git push
ssh nitrogen 'cd ~/nixos-config && git pull && systemctl --user restart llama-server && systemctl --user restart llama-warmup'
ssh nitrogen 'journalctl --user -u llama-server --no-pager -o cat --since "-2min" | grep -E "model buffer size|KV buffer size|RS buffer size|compute buffer size|offloaded.*layers"'
```
Confirm: 66/66 layers offloaded to GPU, zero CPU model buffers, ≥700 MiB free on CUDA0. Then immediately remove `verbosity = 5`.

### Step 2: Run Standardized Coding Benchmark
Execute standard Python implementation test (250 tokens):
```bash
ssh nitrogen '
curl -s -m 120 http://127.0.0.1:5349/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"smart\",\"messages\":[{\"role\":\"user\",\"content\":\"Write a Python class implementing a thread-safe LRU Cache with TTL (time-to-live) expiration using a doubly linked list and a threading.Lock. Include complete type annotations and docstrings.\"}],\"max_tokens\":250,\"stream\":false}" \
  | python3 -c "import json,sys; res=json.load(sys.stdin); print(\"Tokens:\", res[\"usage\"][\"completion_tokens\"])"
'
```

### Step 3: Check Authoritative Metrics
```bash
ssh nitrogen 'journalctl --user -u llama-server --no-pager -o cat --since "-1min" | grep -E "print_timing|draft acceptance"'
```

## Failure Mode Diagnostic Catalog

- Generation drops to ~2.4 tok/s with low GPU utilization:
  - Cause: VRAM overflowed on CUDA0; buffers silently allocated in CPU RAM.
  - Check: `journalctl --user -u llama-server --no-pager -o cat | grep -E "CPU model buffer|offloaded"`
  - Fix: Verify `fit = off`, `ngl = 99`, reduce context `c` or adjust `ts`.

- Process fails to start with `cudaMalloc failed: out of memory`:
  - Cause: CUDA0 exceeded 11,911 MiB budget.
  - Fix: Check layer allocation; shift 1 layer to ROCm0 (e.g. `ts = 28,37` to `26,39`).

- Sudden 4x generation slowdown (~8.5 tok/s):
  - Cause: `ctv = q4_0` enabled; slow software dequantization on gfx906.
  - Fix: Restore `ctv = q8_0`.

- Low draft acceptance rate (<50%) or draft overhead stalls:
  - Cause: Draft head generating too many low-confidence tokens across PCIe.
  - Fix: Ensure `spec-draft-n-max = 1` and `min-p = 0.05`.
