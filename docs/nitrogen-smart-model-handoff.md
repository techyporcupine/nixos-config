# nitrogen "smart" model: OOM fix, context tuning, perf regression — handoff

Written for a fresh agent with no prior context. Read this in full before touching
`nixos/server/llama-server/nitrogen-models.ini` or `nixos/server/llama-server/default.nix`.

## Where things stand right now

An active performance regression was just reverted. **The revert is committed to git but
has NOT been deployed to the `nitrogen` host yet** — the user needs to `git pull` on
nitrogen and restart `llama-server` there. Verify current deployed state before doing
anything else (see "How to check current state" below); don't assume this doc is still
accurate by the time you read it.

## The setup

`nitrogen` is a home server (see repo root `CLAUDE.md`) running an NVIDIA RTX 3080 Ti
(`CUDA0`, 12288 MiB) and an AMD Instinct MI50 (`ROCm0`, gfx906, 32752 MiB, no matrix
cores) side by side. `llama-server`'s built-in router mode manages several model
presets from an INI file (`nixos/server/llama-server/nitrogen-models.ini`), deployed via
a NixOS module (`nixos/server/llama-server/default.nix`) as a `systemd --user` service.
Config path on nitrogen: `~/.config/llama-cpp/models.ini`, a raw (non-nix-store)
symlink to the git-tracked ini, via `mkOutOfStoreSymlink`.

Two models matter here, both kept permanently resident (`sleep-idle-seconds = -1`):
- **`fast`**: Qwen3.5-9B, Q4_K_M, vision-capable (has an mmproj projector). Fixed
  config: `dev = ROCM0`, `fit = off`, `c = 131072`. Not part of any of the problems
  below — don't touch it.
- **`smart`**: Qwen3.8-27B, Q5_K_M, the model all the work below is about. Spans both
  devices: `dev = CUDA0,ROCM0`. Uses `--spec-type draft-mtp` (speculative decoding via
  the model's own MTP/NextN head, not a separate draft model).

`smart`'s architecture (GGUF arch string `qwen35`) is a **hybrid Mamba/attention**
model: `block_count = 65` (64 real transformer blocks + 1 MTP/NextN head at `blk.64`),
`full_attention_interval = 4` — only 1 in 4 layers (~16 of 64) do real self-attention
with a KV cache; the rest are Mamba-style SSM blocks with O(1)-per-sequence recurrent
state, not context-length-dependent. This matters: this is NOT a uniform-per-layer-cost
architecture, and it's why some of the arithmetic below only uses ~16 layers' worth of
KV cost, not 64.

## Problem 1 (SOLVED): smart OOM'd on load

Original symptom: `smart` failed to load with `common_speculative_init_result: failed
to create MTP context` / `cudaMalloc failed: out of memory`. Root causes, all
confirmed against the journal:

1. `fitt` (`--fit-target`) is the VRAM margin `--fit` leaves FREE per device, not a
   target to fill. It was set to `0`, and `--fit` doesn't budget for the MTP draft
   context at all when sizing the main context — that context is built afterward and
   needs its own ~2.3 GiB (measured: 1024 MiB KV + 1296 MiB compute, landing entirely
   on `ROCm0`). With zero margin reserved, there was nothing left for it.
2. `fast`'s mmproj (vision projector) was landing on `CUDA0` despite `dev = ROCM0` —
   `--device` only steers the text model; `mtmd`/clip picks its own backend. This ate
   into the 12 GiB card `smart` also needs.
3. Both models had `load-on-startup = true` and loaded **concurrently**, each running
   `--fit` against momentary free VRAM with no knowledge of the other. This made the
   crash intermittent — the same tensor-split config succeeded once and failed twice
   in the journal history, and it was `fast` that occasionally died instead of `smart`
   depending on which one won the race.

Fixes applied (all still in place, all still correct as far as we know):
- `fitt = 2048` on `[smart]` (broadcast to both devices).
- `no-mmproj-offload = true` on `[fast]` (keeps its projector on CPU, off `CUDA0`).
- **Deterministic load ordering**: added `tp.server.llama-server.warmup` (a NixOS
  option, `nixos/server/llama-server/default.nix`) — a `llama-warmup` systemd oneshot
  unit that requests each listed model's chat-completions endpoint in strict sequence
  (a one-token completion blocks until the model is resident, so a successful response
  IS the readiness signal). Set on `machines/nitrogen.nix`:
  `tp.server.llama-server.warmup = ["fast" "smart"];`. Removed `load-on-startup` from
  `[smart]` so it no longer races `fast` at router boot. The warmup script itself lives
  at `nixos/server/llama-server/llama-warmup.sh` (kept as a real file, not inlined in
  the Nix expression, built via `pkgs.writeShellApplication` + `builtins.readFile`).

**Gotcha we hit while verifying this**: `nh os switch` does NOT restart
`llama-server.service` unless the unit's own `ExecStart` changed — the ini is a raw
symlink read fresh at each process start, decoupled from Nix generation switches. And
`WantedBy=llama-server.service` (how `llama-warmup` is wired in) only triggers when
`llama-server.service` itself transitions from stopped→started — it does NOT
retroactively pull in a newly-added `Wants=` for an already-running target. So after
committing this fix, the OLD router process kept running for nearly a day, with
`smart` still racing `fast` exactly as before, until an actual
`systemctl --user restart llama-server` happened. **Always verify with
`systemctl --user show llama-server -p ActiveEnterTimestamp` that the process
actually restarted after your change, not just that `nh os switch` ran.**

Confirmed working (as of the `db4a890`/`4d07db6`-era restarts): `llama-warmup` journal
shows `fast` requested, ready (~15s), THEN `smart` requested only after — never
simultaneous. `journalctl --user -u llama-server` boot log shows only one
`(startup)`-labeled load (`fast`); `smart`'s spawn happens after `fast` reports ready.

## Problem 2 (SOLVED, but see Problem 3): smart's auto-fit context was small

After the OOM fix, `--fit` (left to auto-choose `c` and `ts`, both unset in the ini)
was landing on `n_ctx = 56576` for `smart` — using roughly the same total VRAM it had
used at `n_ctx = 123136` in an earlier (racy, pre-fix) run, i.e. clearly not using
available headroom well.

A one-shot `verbosity = 5` capture (see "How to run a verbose diagnostic capture"
below) showed `--fit`'s actual search trace: it tries `n_ctx_train = 262144` and the
`-fitc` floor (`4096`) as brackets, then does a layer-split search (46/66 → 44/66 →
45/66 → 66/66 GPU layers) but **every one of those split candidates was tried at the
same n_ctx = 56576**. It picked that ctx value early (looks like a single bisection
step) and stopped once it found a layer split satisfying the `fitt` margin, rather
than continuing to search for the largest ctx the margin would allow. Confirmed by the
actual free VRAM at that point being well clear of the 2048 MiB margin on both devices
(~3.3 GiB free on `CUDA0`, ~6.6 GiB free on `ROCm0`) — i.e. it stopped early, it didn't
hit a real ceiling.

**Key nuance discovered**: `-fitc`/`--fit-ctx` is a MINIMUM ctx floor for `--fit`'s
search, NOT a way to pin the final ctx while letting `--fit` still choose the
tensor-split. The correct mechanism: `--fit`'s own description is "adjust unset
arguments to fit in device memory" — so setting `c` explicitly while leaving `ts`
unset makes `--fit` treat `c` as fixed and still auto-derive the split for it.

Measured buffer breakdown for `smart` at the working `n_ctx = 56576` config (this is
the last config with CONFIRMED-GOOD throughput, see Problem 3):

```
                        CUDA0        ROCm0
model                  5786.63     12284.53
KV (main ctx)            587.03      1291.47
RS (SSM state)           847.88      1546.12
compute (main ctx)       762.33       762.33
MTP KV                      —        1024.00
MTP compute                 —        1296.06
──────────────────────────────────────────────
smart subtotal          7983.87     18204.51
fast (unchanged)            ~1        7934.56
──────────────────────────────────────────────
device total            12288        32752
used                     ~8983        26139
free                     ~3305         6613
```

Per-token KV cost derived from this (and matches GGUF metadata exactly:
`16 attention layers × 4 KV heads × 256 dim × 2 (K+V) × 1.0625 B/elem (q8_0) =
34,816 B/token` total, split ~10,876 B/token on `CUDA0` / ~23,940 B/token on `ROCm0`
per the measured split ratio). Note the compute buffer is NOT ctx-independent — it
varies with which/how-many layers land on each device (762.33 MiB in this split vs.
1282.33 MiB in the older 123136-ctx run's different split).

## Problem 3 (ACTIVE, being reverted right now — verify!): severe tps regression

Attempted fix for Problem 2: added `c = 131072` to `[smart]`, left `ts` unset,
expecting `--fit` to auto-derive a good split for the larger fixed ctx (matching the
math above, which suggested comfortable headroom for well beyond 131072).

**Result after deploying**: `smart` correctly loaded at `n_ctx = 131072` (confirmed via
`/v1/models`), memory usage matched full-GPU-offload predictions closely on both
devices (ruled out any CPU fallback) — but real-world generation speed collapsed to
**~2.4–2.9 tokens/sec**, against a user-reported prior baseline of ~25 tok/s. Verified
directly, three separate real generations, consistent:

```
tg = 2.43 t/s  (383 tokens generated)
tg = 2.69 t/s  (150 tokens generated)
tg = 2.91 t/s  (my own 80-token test)
```

During generation, both GPUs sampled at **0–12% utilization** — mostly idle, not
compute-bound. Speculative decoding acceptance was mediocre but not obviously broken:
`draft acceptance = 0.355` (198/558) and `0.407` (81/199), mean accepted chain length
~2.1–2.2.

**Working hypothesis, NOT yet proven**: pinning `c = 131072` while leaving `ts` unset
forced `--fit` to recompute the entire tensor-split from scratch for the much larger
context. `--fit`'s split search is a pure memory bin-packing algorithm — it has no
concept of compute efficiency or PCIe cross-device transfer cost. A different split
boundary across two very different, PCIe-connected devices (fast 3080 Ti + MI50, which
is slow per-op with no matrix cores) can fit comfortably in VRAM while being far worse
for throughput — especially given the interleaved attention/Mamba layer pattern, where
an unlucky cut point could force many more cross-device round-trips per forward pass
than the split that happened to be chosen at ctx=56576.

**What we do NOT have**: a verbosity=5 capture of the actual tensor-split chosen at
ctx=131072 (default verbosity doesn't log per-layer offload placement), nor a directly
measured tok/s baseline at ctx=56576 from before this specific change (the "~25 tok/s"
figure is the user's recollection, not something measured in this investigation). So
the hypothesis above is plausible and consistent with everything observed, but not
confirmed as the exact mechanism.

**Action just taken**: removed `c = 131072` from `[smart]` in
`nixos/server/llama-server/nitrogen-models.ini`, reverting to auto-fit (back to the
last CONFIRMED-reasonable-throughput config, ctx≈56576 — though note we never
explicitly benchmarked tok/s at 56576 either; we're reverting because it's the last
state the user reports as fine, not because we measured it ourselves). **This revert
is committed but not yet deployed** — needs `git pull` + `systemctl --user restart
llama-server` on nitrogen, then confirm both: (a) `smart`'s `/v1/models` reports
`n_ctx` back around 56576, and (b) a real generation returns to acceptable tok/s.

## Recommended next steps (in order)

1. **Confirm the revert actually restored speed.** Don't assume — run a real
   generation (see "How to test tok/s" below) and check the `print_timing` log line's
   `tg = ... t/s` figure is back to something like the user's expected range.
2. If speed is restored: the context-size question (Problem 2) is still open. Do NOT
   just re-add `c = 131072` and hope. Get an explicit, measured tensor-split first:
   - Run the verbosity=5 capture procedure below AT THE CURRENT (reverted, working)
     config to get the actual `ts` ratio `--fit` is using now.
   - Manually set BOTH `c` (target ctx) AND `ts` (using that known-working ratio,
     scaled) explicitly, so `--fit` isn't asked to re-derive the split for a different
     ctx target.
   - **Benchmark tok/s before deploying to the live preset.** A verbose reload alone
     isn't enough — Problem 3 loaded fine and used the "right" amount of memory, and
     was still 10x slower. Test actual generation throughput, ideally via a spare-port
     manual `llama-server` invocation with the candidate config, before touching the
     deployed INI.
3. If speed is NOT restored by the revert: the regression isn't from the `c` pin
   specifically. Re-check what else changed recently — `no-mmproj = true` on `[smart]`
   (added by the user directly; confirmed to be a no-op since `smart`'s HF repo has no
   mmproj to begin with, so almost certainly unrelated) and `load-mode = none`
   (replaced a deprecated `no-mmap = true`; semantically should be equivalent — `none`
   means "no special loading mode" per `--help`, matching disabled mmap — but wasn't
   independently re-verified after being deployed). Bisect by reverting one variable
   at a time and re-testing tok/s.

## Constraints / house rules (from the repo's CLAUDE.md and this session)

- **nitrogen is production.** Never SSH in and hand-edit config directly — it's
  managed declaratively via Nix + git. Diagnostic or fix commits go through the normal
  edit → commit flow in this repo; the human deploys via `git pull` +
  `nh os switch`/`systemctl --user restart llama-server` on their own machine. Ask
  before proposing another restart-requiring change; they've been doing every restart
  themselves throughout this investigation.
- **Do not add explanatory comments to the INI file.** The user explicitly asked for
  this to stop — put rationale in commit messages, not in `nitrogen-models.ini`. (Nix
  module comments in `default.nix`/doc comments in `llama-warmup.sh` are fine; this
  restriction is specifically about the INI.)
- `fast` must stay untouched and resident — don't touch its config while
  investigating `smart`.
- Don't sacrifice `ub = 2048` on `smart`/`fast` for memory headroom — it's deliberate:
  gfx906 (MI50) has no matrix cores, so large ubatch is a real prompt-processing
  throughput win there, at no cost to token generation.
- Don't disable `--spec-type draft-mtp` as a quick fix without first measuring whether
  it's actually net-positive at the current acceptance rate (~35–40% observed) — it's
  possible but not yet confirmed that it's costing more than it saves.

## How to check current state

```bash
ssh nitrogen 'cd ~/nixos-config && git log --oneline -5 -- nixos/server/llama-server/; git status --short'
ssh nitrogen 'systemctl --user show llama-server -p ActiveEnterTimestamp'
ssh nitrogen 'systemctl --user show llama-warmup -p ActiveEnterTimestamp,Result,ActiveState,SubState'
ssh nitrogen 'journalctl --user -u llama-warmup --no-pager -o short-iso --since "-30min"'
ssh nitrogen 'curl -s http://127.0.0.1:5349/v1/models | python3 -c "
import json,sys
d=json.load(sys.stdin)
for m in d[\"data\"]:
    print(m[\"id\"], \"->\", m[\"status\"][\"value\"], m.get(\"meta\",{}).get(\"n_ctx\"))
"'
```

Confirm the local repo's HEAD matches nitrogen's checked-out HEAD before trusting
anything in this doc as still-current — a lot of this investigation involved the two
being out of sync at various points (a config change committed here isn't live until
the user deploys it).

## How to test tok/s

```bash
ssh nitrogen '
time curl -s -m 120 http://127.0.0.1:5349/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"smart\",\"messages\":[{\"role\":\"user\",\"content\":\"Write a long, detailed story about a lighthouse keeper.\"}],\"max_tokens\":150,\"stream\":false}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)[\"usage\"])"
'
```

Then pull the authoritative number straight from llama.cpp's own report rather than
computing it from wall-clock time:

```bash
ssh nitrogen 'journalctl --user -u llama-server --no-pager -o cat --since "-2min" \
  | grep -E "print_timing|draft acceptance"'
```

Look for the `eval time = ... ms / N tokens ( ... ms per token, X.XX tokens per
second)` line and the `draft acceptance = ...` line.

## How to run a verbose diagnostic capture

This is the pattern used successfully twice in this investigation — a one-line,
reversible, two-commit diagnostic:

1. Add `verbosity = 5` to the `[*]` section of `nitrogen-models.ini` (temporary — do
   NOT leave this in permanently, it's very noisy). Commit it with a clear "temporary
   diagnostic" message.
2. Ask the user to deploy (push/pull/restart).
3. Once `llama-warmup` shows `Result=success` for the new run, pull the log:
   ```bash
   ssh nitrogen 'journalctl --user -u llama-server --no-pager -o cat --since "<restart-time>"'
   ```
4. Find `smart`'s port via `grep "spawning server instance with name=smart"`, then
   filter all lines tagged `[<port>]` for `model buffer size|KV buffer size|RS buffer
   size|compute buffer size|offloaded.*layers|n_seq_max|n_ctx |CUDA_Host|ROCm_Host`.
5. Revert the `verbosity = 5` line in a follow-up commit immediately after capturing
   what you need — don't leave it deployed.

## Full commit history for this work (newest first)

```
6a14e45 style: drop explanatory comment on smart's c setting
4d07db6 fix(llama-server): pin smart's ctx to 131072, stop relying on fit's choice
3d9d71c Revert "diag(llama-server): temporarily bump verbosity to capture smart's buffer sizes"
b2b22a2 diag(llama-server): temporarily bump verbosity to capture smart's buffer sizes
b50e5a0 fix: mmap and mmproj                          (user's own commit)
894a7be fix: mmap on llama.cpp                          (user's own commit)
db4a890 refactor(llama-server): move warmup script out of the nix expression
3b2a7bb fix(llama-server): stop smart OOMing on load, make startup deterministic
```

Plus the not-yet-deployed revert of `4d07db6`'s `c = 131072` (see top of this doc —
check `git log` yourself for the actual hash, since this doc may be stale by the time
you read it).
