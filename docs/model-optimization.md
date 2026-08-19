# Model Optimization & Quantization Benchmark Guide

Guide for testing new model quants, tuning context size, adjusting tensor splits, and validating speculative decoding on `nitrogen`.

## System & Architecture Context

- Hardware: `CUDA0` (NVIDIA RTX 3080 Ti, 12,288 MiB total, ~11,911 MiB usable) and `ROCm0` (AMD Instinct MI50 gfx906, 32,752 MiB total, ~24,300 MiB usable after `fast`).
- `fast`: Qwen3.5-9B, permanently resident on `ROCm0` (`c = 131072`, `dev = ROCM0`, `no-mmproj-offload = true`, ~7.9 GiB VRAM). Do not touch.
- `smart`: Qwen3.8-27B, hybrid Mamba/attention (65 total blocks: 64 transformer/SSM blocks + 1 MTP draft head at `blk.64`).
  - Only 1 in 4 layers (16 of 64) are self-attention with KV cache.
  - The remaining 48 layers are SSM recurrent blocks with constant O(1) state per sequence (~50 MiB/layer), invariant to context length.
- Known Stable Baseline (`Q5_K_M`): `c = 98304`, `ts = 28,37` (29 layers on CUDA0, 37 on ROCm0), `spec-type = draft-mtp`, `spec-draft-n-max = 1`, `min-p = 0.05`, yielding ~32.8 tok/s eval throughput on code with ~95% draft acceptance.

## Rules & Constraints

- Target config: [`nixos/server/llama-server/nitrogen-models.ini`](file:///home/bowmanjd/devel/caleb-nix/nixos/server/llama-server/nitrogen-models.ini)
- No comments in the INI file (commit messages only).
- Retain `fit = off` and `ngl = 99`: ensures memory shortfalls fail loudly at startup with an OOM rather than silently falling back to CPU host memory at 2 tok/s.
- Retain `ctk = q8_0, ctv = q8_0`: do NOT use `ctv = q4_0` (gfx906 lacks 4-bit matrix cores, causing a 4x slowdown during attention dequantization).
- Deploy pipeline: Git commit -> push -> SSH git pull -> restart services.

## Testing Workflow for a New Quant

### Step 1: Initial Deploy with Diagnostic Verbosity
Add `verbosity = 5` temporarily to `[*]` in [`nixos/server/llama-server/nitrogen-models.ini`](file:///home/bowmanjd/devel/caleb-nix/nixos/server/llama-server/nitrogen-models.ini) to measure exact layer weights and buffer allocations:

```ini
[*]
sleep-idle-seconds = 1800
jinja = true
fa = on
fitt = 0
load-mode = none
offline = true
verbosity = 5

[smart]
hf = <candidate-hf-repo-and-quant>
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

Deploy and inspect memory allocations:
```bash
git add nixos/server/llama-server/nitrogen-models.ini && git commit -m "diag(llama-server): test quant <name> with verbosity=5" && git push
ssh nitrogen 'cd ~/nixos-config && git pull && systemctl --user restart llama-server && systemctl --user restart llama-warmup'
ssh nitrogen 'journalctl --user -u llama-server --no-pager -o cat --since "-2min" | grep -E "model buffer size|KV buffer size|RS buffer size|compute buffer size|offloaded.*layers"'
```

Verify:
1. `offloaded 66/66 layers to GPU`
2. No `CPU*` buffers.
3. Record exact model buffer size per layer on CUDA0.
4. Immediately remove `verbosity = 5` from `[*]` in a follow-up commit to avoid noisy logs.

### Step 2: Shift Tensor Split Toward CUDA0
A smaller quant (e.g. `UD-Q4_K_XL` vs `Q5_K_M`) frees ~2.5–3 GB total VRAM.

Sizing budget on CUDA0 (capacity: 11,911 MiB usable):
- Weights = L layers × weight_per_layer
- KV cache (at `c = 98304`, `q8_0`) = ~204 MiB per attention layer (every 4th layer: 3, 7, 11, 15, 19, 23, 27, 31...)
- RS state = ~50 MiB per SSM layer
- Compute buffer = ~1,088 MiB
- Safety headroom target: ≥500 MiB free

Experiments to run:
1. Increment layers on CUDA0: try `ts = 29,36` (30 layers), then `ts = 30,35` (31 layers), or `ts = 31,34` (32 layers).
2. Expand context: test `c = 131072` at the optimal split.

### Step 3: Validate Speculative Decoding (MTP)
With smaller quant weights, draft step execution latency on ROCm0 is reduced, which may make multiple draft tokens viable.

Test sequence:
1. `spec-draft-n-max = 1` (baseline).
2. `spec-draft-n-max = 2`: test if 2 draft tokens beat 1 draft token with the lighter quant.
3. `spec-type = none`: run non-speculative baseline to measure net MTP speedup percentage.

### Step 4: Standard Benchmark Command
Run the standardized Python coding benchmark (250 tokens):
```bash
ssh nitrogen '
curl -s -m 120 http://127.0.0.1:5349/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"smart\",\"messages\":[{\"role\":\"user\",\"content\":\"Write a Python class implementing a thread-safe LRU Cache with TTL (time-to-live) expiration using a doubly linked list and a threading.Lock. Include complete type annotations and docstrings.\"}],\"max_tokens\":250,\"stream\":false}" \
  | python3 -c "import json,sys; res=json.load(sys.stdin); print(\"Tokens:\", res[\"usage\"][\"completion_tokens\"])"
'
```

Extract authoritative throughput and acceptance:
```bash
ssh nitrogen 'journalctl --user -u llama-server --no-pager -o cat --since "-1min" | grep -E "print_timing|draft acceptance"'
```

Success criteria:
- Throughput exceeds baseline (≥32.8 tok/s).
- Valid, non-corrupted code generation.
- Full GPU offload without OOM or CPU fallback.
