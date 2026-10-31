# ClaudeSearch v4: the full loop

> **Note:** this describes the full system as it runs on my own machine. The loop scripts named below (`_scripts/…`) are part of my private setup and are not in this repo. What this repo ships is the portable improvement-cycle skill described in the [README](../README.md).

v4 introduced the dual-instance split and Connect+Act mode — closing the loop from knowledge generation to actual code changes. The original v3 system produced 461 synthesis notes but zero code changes. v4 fixed that.

### Instance Roles

```
┌─────────────────────────────────┐     ┌──────────────────────────────────────┐
│  Instance B  (local GPU, free)  │     │  Instance A  (Claude API)            │
│                                 │     │                                      │
│  Model: MoE 35B-A3B (Vulkan)   │     │  Model: Haiku (routine) /            │
│  Speed: 149 tok/s               │     │         Sonnet (--burst, deep work)  │
│  Cost:  $0                      │     │  Cost:  ~$2/day budget               │
│                                 │     │                                      │
│  Modes:                         │     │  Modes:                              │
│  ├─ R  Research (30%)           │     │  ├─ C  Connect+Act  (60%)            │
│  └─ S  Synthesize (70%)         │     │  ├─ I  Improve      (15%)            │
│                                 │     │  ├─ R  Research     (15%)            │
│  Output: knowledge notes,       │     │  └─ S  Synthesize   (10%)            │
│          cross-domain synthesis │     │                                      │
│  ~510 cycles/hour               │     │  Output: real code changes,          │
│                                 │     │          verified improvements       │
│                                 │     │  ~6 cycles/hour                      │
└─────────────────────────────────┘     └──────────────────────────────────────┘
                    │                                      │
                    └──────────────┬───────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │          Shared State               │
                    │  improvement-log.jsonl              │
                    │  file-cooldowns.json                │
                    │  domain-rotation.json               │
                    │  quality-scores.tsv                 │
                    └─────────────────────────────────────┘
```

### Mode Descriptions

| Code  | Name        | Instance | Model           | What it does                                                                  |
| ----- | ----------- | -------- | --------------- | ----------------------------------------------------------------------------- |
| **C** | Connect+Act | A        | Sonnet/Haiku    | Reads a knowledge note, finds a real gap in code, implements if quality ≥ 4/5 |
| **I** | Improve     | A        | Sonnet/Haiku    | Scans quality scores, diagnoses failing tasks, applies fixes                  |
| **R** | Research    | A+B      | Haiku / MoE 35B | Generates new knowledge notes from external sources                           |
| **S** | Synthesize  | A+B      | Haiku / MoE 35B | Creates cross-domain synthesis notes from existing knowledge                  |

### Connect+Act: The Key Mode

Connect+Act (60% of Instance A cycles) is the mode that converts knowledge into code:

```
Step 0: Search vault for high-value notes
        python3 vault-search.py "topic" --top 5

Step 1: Deep-read the best note, follow 1-2 connections

Step 2: Find matching code — look for concrete mismatches
        between what the note recommends and what code does

Step 3: Quality gate (score 1-5)
        5 = clear bug fix or missing feature
        4 = meaningful optimization       ← ACT threshold
        3 = nice-to-have                  ← SKIP
        < 3 = theoretical only            ← SKIP

Step 4: Capture BEFORE state (measurable)

Step 5: Implement the change

Step 6: Verify improvement (re-measure, confirm)

Step 7: Log to improvement-log.jsonl with quality score
```

Linesheet (production SaaS) is suggest-only — improvements go to `linesheet-suggestions.md` for human review instead of direct edits.

### Dynamic Weight Adaptation

Mode weights update every cycle based on recent improvement quality. If Connect+Act is scoring consistently high, its weight increases. If a mode produces no improvements, its weight drops back to baseline. This prevents the system from getting stuck in low-value modes.

A bash subshell bug was fixed in this version — weight updates now correctly persist across cycles.

### Infrastructure Details

**Circuit breaker**: 5 consecutive failures triggers a 10-minute cooldown. Prevents thrashing when llama-server is unavailable.

**File cooldown system** (adaptive, quality-based):

- quality ≥ 4: 12h cooldown (high-value files, revisit sooner)
- quality = 3: 24h cooldown (baseline)
- quality ≤ 2: 48h cooldown (avoid over-optimizing low-value targets)

**Domain rotation**: Forces domain switch after 3 consecutive improvements in the same area.
Domains: `vault-scripts`, `website`, `gpu-infra`, `linesheet`, `knowledge-quality`.

**llama-server circuit breaker**: Separate from the main circuit breaker. Tracks llama-server health with exponential backoff + jitter. Falls back to Ollama if llama-server is unavailable. State machine: closed → open → half-open → closed.

### Key Hardware Discovery

Running MoE models (Mixture of Experts) on Vulkan llama-server requires `--reasoning off`:

```bash
# Without --reasoning off:
# All output routes to reasoning_content field → content field is empty → 0 tokens
# Speed: ~48 tok/s (thinking tokens consumed silently)

# With --reasoning off:
# Output routes to content field correctly
# Speed: 149 tok/s — 3.1x improvement
```

This was discovered after observing that llama-server responses were returning empty strings despite the model running. Without this flag, every Synthesize cycle produced nothing.

### Key Metrics

| Metric                | Value                                                           |
| --------------------- | --------------------------------------------------------------- |
| Improvements logged   | 163                                                             |
| Average quality score | 4.28 / 5                                                        |
| Score distribution    | 5★: 28%, 4★: 71%, 3★: 1%                                        |
| Instance B speed      | 149 tok/s (Vulkan, MoE 35B-A3B)                                 |
| Instance B cycles     | ~510/hour                                                       |
| Instance A cycles     | ~6/hour (Claude API)                                            |
| Domains covered       | vault-scripts, website, gpu-infra, linesheet, knowledge-quality |

### Hardware Requirements

To run Instance B (local knowledge generation):

- GPU with 16GB+ VRAM
- [llama.cpp](https://github.com/ggerganov/llama.cpp) with Vulkan backend
- MoE 35B-A3B model (Q4 quantization fits in 16GB VRAM)
- `--reasoning off` flag — critical for MoE models (see above)

Instance A (Claude API only) works on any machine with internet access and a Claude API key.

### Launch Commands

```bash
# Instance B: continuous knowledge generation (local GPU, free)
bash _scripts/cs-v3-loop.sh --instance B &

# Instance A: Connect+Act improvement cycles (Claude API)
bash _scripts/cs-v3-loop.sh --instance A &

# Instance A burst mode (Sonnet, deeper work, 20 cycles)
bash _scripts/cs-v3-loop.sh --instance A --burst 20 &

# Status check
bash _scripts/cs-v3-loop.sh --status
```

### Key Scripts (private setup, not included)

| Script                                          | Purpose                                                                      |
| ----------------------------------------------- | ---------------------------------------------------------------------------- |
| `_scripts/cs-v3-loop.sh`                        | Main loop (~1400 lines) — mode dispatch, circuit breakers, weight adaptation |
| `_scripts/heartbeat-collectors/cs-connector.sh` | Connect+Act collector — domain-aware knowledge note selection                |
| `_scripts/v3-file-cooldown.py`                  | Adaptive cooldown tracker with quality-based TTLs                            |
| `_scripts/v3-domain-rotation.py`                | Forces domain rotation after 3 consecutive same-domain improvements          |
