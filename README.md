# ClaudeSearch

**Self-improving development infrastructure. Your project workspace trains itself.**

> "What if your codebase got better while you slept?"

ClaudeSearch is an autonomous improvement system for software projects. It treats your workspace like a model to be trained: quality scores are the loss function, improvement cycles are training steps. It finds bottlenecks, root-causes them, applies fixes, measures impact, and iterates — entirely autonomously, overnight, while you're focused on something else.

Built and battle-tested over weeks of continuous operation:

- **6,000+ knowledge notes** generated autonomously (local MoE at 149 tok/s)
- **163 code improvements** logged with quality gate (avg 4.28/5)
- **5 production feature specs** generated for a live SaaS app from knowledge notes
- **Dual-instance architecture**: local GPU builds the knowledge library (free), Claude implements real changes
- **Blog pipeline, learning engine, heartbeat system** all maintained autonomously

---

## v4 Architecture

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

- GPU with 16GB+ VRAM (tested: AMD RX 7900 XTX, 24GB)
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

### Key Scripts

| Script                                          | Purpose                                                                      |
| ----------------------------------------------- | ---------------------------------------------------------------------------- |
| `_scripts/cs-v3-loop.sh`                        | Main loop (~1400 lines) — mode dispatch, circuit breakers, weight adaptation |
| `_scripts/heartbeat-collectors/cs-connector.sh` | Connect+Act collector — domain-aware knowledge note selection                |
| `_scripts/v3-file-cooldown.py`                  | Adaptive cooldown tracker with quality-based TTLs                            |
| `_scripts/v3-domain-rotation.py`                | Forces domain rotation after 3 consecutive same-domain improvements          |

---

## The Big Idea

Andrej Karpathy wrote about [autoresearch](https://github.com/karpathy/autoresearch) — training neural networks autonomously. ClaudeSearch applies that same loop to _infrastructure_:

```
Neural network training:        ClaudeSearch:
  weights     ←→  configs, scripts, prompts
  loss        ←→  quality scores (0-10 per task)
  gradient    ←→  root-cause analysis
  update      ←→  fix + verify
  epoch       ←→  improvement cycle
```

The insight is that your project's infrastructure — its automation scripts, agent prompts, deployment pipelines, build configs — is itself a kind of model. It has parameters (the scripts and configs), it has measurable performance (quality scores, success rates, task completions), and it can be improved systematically.

When a task scores 6/10 three runs in a row, that's a signal. ClaudeSearch investigates it, finds the root cause (stale data? broken pipeline? wrong model?), applies a fix, and watches whether the score climbs. If it doesn't, it digs deeper. This is exactly the loop that makes neural network training work — applied to the unglamorous but critical layer underneath your code.

### Why This Matters

Most developers fix infrastructure reactively: something breaks, you notice, you fix it. ClaudeSearch makes it proactive. Issues are caught when quality starts dropping, before anything is visibly broken. The fix often happens overnight.

The system also compounds. Each improvement cycle leaves a trace: what failed, what was tried, what worked. Over weeks, ClaudeSearch develops a detailed picture of your project's failure modes and knows which fixes work for which patterns. It gets better at improving your project the more it runs.

---

## What It Does

### The Core Cycle

```
quality-triage → diagnose → root-cause → fix → verify → log → repeat
```

1. **Triage**: Scan quality scores for persistent drops (3+ consecutive runs below threshold)
2. **Diagnose**: Investigate the failing task — read its config, check its outputs, trace the pipeline
3. **Root-cause**: Find the actual cause, not the symptom. (Example: blog pipeline failing isn't a network issue — the model was changed to a code-specialized model that produces filler text instead of prose)
4. **Fix**: Apply the minimal change that addresses the root cause
5. **Verify**: Run the task again, confirm the score improves
6. **Log**: Record what was found and fixed in the improvement log

### Three Execution Modes

**Interactive (skill)**: Run `/autoresearch` in Claude Code for a guided session. You see the diagnosis in real-time, can intervene, and approve fixes before they're applied. Best for learning the system and for changes you want to review.

**Background agent (batch)**: Trigger the skill as a background agent for unattended runs. Fixes are applied automatically, results logged. Best for overnight maintenance cycles.

**Team session (parallel)**: Spawn multiple parallel agents, each investigating a different failure domain simultaneously. 5-10 agents in parallel is standard. Results are merged into a single improvement batch. Best for high-velocity sessions when many things need attention.

### What Gets Fixed

ClaudeSearch isn't limited to one type of problem. It operates across:

- **Automation scripts**: Broken shell scripts, incorrect paths, wrong arguments
- **Agent prompts**: Prompts that consistently produce low-quality output get rewritten
- **Pipeline configs**: Data pipelines with silent failures (wrong field names, missing transforms)
- **Model routing**: Tasks assigned to wrong models (code model writing prose, cheap model doing architecture)
- **Build/deploy**: Pre-deploy checks that are silently failing, deploy hooks that aren't running
- **Dependency maps**: Tasks running in the wrong order, missing dependencies causing stale data

---

## How It Works

### The Autonomous Pipeline

```
┌─────────────────┐
│  quality-triage  │ ← Scans quality-scores.tsv for drops
└────────┬────────┘
         │ failing tasks
         ▼
┌─────────────────┐
│   root-cause    │ ← Reads configs, traces pipelines, checks outputs
└────────┬────────┘
         │ diagnosis
         ▼
┌─────────────────┐
│    auto-fix     │ ← Pattern-matches diagnosis → applies known fix templates
└────────┬────────┘
         │ fix applied
         ▼
┌─────────────────┐
│    verify       │ ← Runs the task once, checks new quality score
└────────┬────────┘
         │ score improved?
         ├── yes → log improvement, mark resolved
         └── no  → escalate (try harder fix, notify human)
```

### Quality Scoring

Every automated task in ClaudeSearch gets a quality score after each run (0-10). Scores are logged to `quality-scores.tsv`:

```tsv
timestamp          task                    score  model           notes
2026-03-19T02:00   blog-writer             3      qwen2.5-coder   filler text, no structure
2026-03-19T02:00   knowledge-analyst       7      llama3.1:8b     partial data only
2026-03-19T02:00   research-session        9      claude-sonnet   strong synthesis
```

The triage script flags tasks where the rolling average drops below threshold (default: 7.0) for 3+ consecutive runs. This filters out one-off noise and targets persistent problems.

### The Experiment Queue

For problems that require exploration (e.g., "which model is best for this task?"), ClaudeSearch maintains an experiment queue:

```jsonl
{
  "id": "e001",
  "hypothesis": "gemma3:12b writes better prose than qwen2.5-coder for blog posts",
  "task": "blog-writer",
  "variable": "model",
  "values": [
    "gemma3:12b",
    "qwen2.5-coder:14b"
  ],
  "metric": "quality_score",
  "status": "pending"
}
```

The experiment runner works through the queue, runs each hypothesis, records results, and promotes winners to the active config. This is how model routing decisions get made empirically rather than by guess.

### Pattern Matching

After enough runs, recurring failure patterns become templates. When auto-fix sees a diagnosis matching a known pattern, it applies the template fix directly — no investigation needed. New patterns are added to `patterns/failure-patterns.md` as they're discovered.

---

## CLI Compatibility

ClaudeSearch was built for Claude Code but the core concept works with any AI CLI that has tool access.

### Claude Code (Native)

Full native support. All features work.

```bash
# Install
git clone https://github.com/vachsark/claudesearch
cd your-project
bash /path/to/claudesearch/install.sh

# Run
claude   # then type: /autoresearch
```

The skill lives in `.claude/skills/autoresearch/SKILL.md`. Claude Code auto-discovers and registers it.

### OpenAI Codex CLI

Codex CLI reads `AGENTS.md` from your project root (and the global `~/.codex/AGENTS.md`); it does not read `.codex/AGENTS.md` inside a project. Put the autoresearch protocol there — the core logic is identical.

```bash
# Install: add the protocol to your project's AGENTS.md
cat claudesearch/.claude/skills/autoresearch/SKILL.md >> your-project/AGENTS.md

# Run (Codex CLI syntax)
codex "run one ClaudeSearch improvement cycle on this project"
```

See `.codex/AGENTS.md` for the full Codex setup guide.

### Gemini CLI

Gemini CLI loads `GEMINI.md` from your project root by default (not `.gemini/AGENTS.md`). Put the autoresearch protocol there.

```bash
# Install: add the protocol to your project's GEMINI.md
cat claudesearch/.claude/skills/autoresearch/SKILL.md >> your-project/GEMINI.md

# Run (Gemini CLI syntax)
gemini "run one ClaudeSearch improvement cycle on this project"
```

See `.gemini/AGENTS.md` for the full Gemini setup guide.

### Any CLI with Tool Access

The core loop — diagnose → fix → verify — works with any AI CLI that can read files, write files, and run shell commands. You don't need the skill files. Just give your AI this prompt:

```
You are a self-improving infrastructure agent. Your job:
1. Read quality-scores.tsv. Find tasks with rolling average < 7.0 for 3+ runs.
2. For each failing task: read its config, trace its pipeline, find the root cause.
3. Apply the minimal fix that addresses the root cause.
4. Run the task once to verify the score improved.
5. Log what you found and fixed to prompt-results.jsonl.
Repeat until no tasks are below threshold or you've made 20 fixes.
```

---

## Getting Started

### Minimal Setup (10 minutes)

You just need two things: the skill file and a quality tracking mechanism.

**Step 1**: Clone and copy the skill

```bash
git clone https://github.com/vachsark/claudesearch
mkdir -p your-project/.claude/skills/autoresearch
cp claudesearch/.claude/skills/autoresearch/SKILL.md your-project/.claude/skills/autoresearch/
```

**Step 2**: Create a quality scores file

```bash
mkdir -p your-project/.claudesearch
cp claudesearch/templates/quality-scores.tsv your-project/.claudesearch/
```

Edit `quality-scores.tsv` to add your actual automated tasks and their recent scores. Even 3-4 scores per task is enough to start.

**Step 3**: Run your first cycle

```bash
cd your-project
claude   # then: /autoresearch
```

The skill will scan your quality scores, find the worst-performing task, diagnose it, and propose a fix. On the first run, just watch — understand what it finds before letting it auto-apply.

### Install Script

```bash
bash /path/to/claudesearch/install.sh your-project
```

The install script takes an optional project directory (default: current directory) and will:

1. Create `.claudesearch/` with `quality-scores.tsv` and `prompt-results.jsonl`
2. If Claude Code is detected, copy the skill to `.claude/skills/autoresearch/SKILL.md`

Scheduled runs (heartbeat), the experiment queue, and the self-healing loop are not set up by the script — see the sections below for how they work.

### What to Track

Start with your highest-leverage automated tasks:

- Build and deploy pipelines
- Test suites (track pass rates, not just pass/fail)
- Code generation tasks (if you use AI to generate code)
- Data pipelines (especially if they process text/documents)
- Any automation that produces output you evaluate manually

You don't need to track everything. 5-10 well-chosen tasks give ClaudeSearch enough signal to find real improvements.

---

## Architecture

### Directory Layout

```
your-project/
├── .claude/
│   └── skills/
│       └── autoresearch/
│           └── SKILL.md          # Core skill (Claude Code)
├── .codex/
│   └── AGENTS.md                 # Codex CLI equivalent
├── .gemini/
│   └── AGENTS.md                 # Gemini CLI equivalent
└── .claudesearch/                # Created by install.sh (first two files)
    ├── quality-scores.tsv        # Per-task quality history
    ├── prompt-results.jsonl      # Improvement log
    ├── experiment-queue.jsonl    # Pending experiments
    ├── experiment-results.jsonl  # Completed experiment results
    └── task-dependency-map.md    # Task execution order
```

### The Self-Healing Loop

```
                    ┌──────────────────────────────────┐
                    │         Scheduled Trigger         │
                    │    (nightly, or on-demand)        │
                    └──────────────┬───────────────────┘
                                   │
                    ┌──────────────▼───────────────────┐
                    │         quality-triage            │
                    │  Finds tasks below threshold       │
                    └──────────────┬───────────────────┘
                          ┌────────┴────────┐
                          │                 │
               ┌──────────▼──┐     ┌────────▼──────────┐
               │  Known      │     │  Unknown           │
               │  Pattern    │     │  Pattern           │
               └──────┬──────┘     └────────┬──────────┘
                      │                     │
               ┌──────▼──────┐     ┌────────▼──────────┐
               │ Apply       │     │ Deep Diagnose      │
               │ Template    │     │ (read all related  │
               │ Fix         │     │  files, trace)     │
               └──────┬──────┘     └────────┬──────────┘
                      │                     │
                      └─────────┬───────────┘
                                │
                    ┌───────────▼──────────────────────┐
                    │           Verify                  │
                    │   Run task, check new score       │
                    └───────────┬──────────────────────┘
                         ┌──────┴──────┐
                         │             │
                   ┌─────▼─────┐  ┌───▼──────────────────┐
                   │  Score    │  │  Score unchanged /     │
                   │  improved │  │  dropped               │
                   └─────┬─────┘  └───┬──────────────────┘
                         │            │
                   ┌─────▼─────┐  ┌───▼──────────────────┐
                   │  Log +    │  │  Escalate / Add to     │
                   │  Commit   │  │  experiment queue      │
                   └───────────┘  └────────────────────────┘
```

### Model Routing

Different tasks warrant different models. ClaudeSearch uses a two-tier routing strategy by default:

| Task Type                      | Default Model           | Reason                      |
| ------------------------------ | ----------------------- | --------------------------- |
| Read-only scans, triage        | Fast/cheap local model  | No generation needed        |
| Root-cause analysis            | Mid-tier (Sonnet-class) | Needs reasoning, not scale  |
| Complex architecture decisions | Top-tier (Opus-class)   | Rare, worth the cost        |
| Verification runs              | Same as original task   | Apples-to-apples comparison |
| Experiment evaluation          | Mid-tier                | Consistent judging          |

See `skills/model-routing.md` for the full decision tree.

---

## Real Examples

These are verbatim findings from a single session. No cherry-picking — these were the first things the system found.

### Example 1: The Silent Copy Bug

**Task**: `session-reflection` (summarizes the day's work)
**Symptom**: Quality score 4/10 for 6 consecutive runs
**Diagnosis**: The task prompt included an example output to illustrate format. The agent was copying the example verbatim instead of generating new content.
**Fix**: Moved the example to a separate `## Example (DO NOT COPY)` section with an explicit instruction
**Result**: Score went from 4/10 to 8/10 on the next run

The fix took 2 minutes. The task had been broken for weeks.

### Example 2: The Wrong Model

**Task**: `blog-writer` (writes blog posts from research briefs)
**Symptom**: Posts full of code blocks, technical jargon, no narrative flow
**Diagnosis**: The model config was set to `qwen2.5-coder:14b` — a code-specialized model
**Root cause**: Someone had swapped the model during a debugging session and never swapped it back
**Fix**: Changed model back to `gemma3:12b`, added a comment explaining why
**Result**: Blog pipeline publishing again after 9 days broken

### Example 3: The Data Window Bug

**Task**: `knowledge-analyst` (finds patterns across recent knowledge notes)
**Symptom**: Score 5/10, reports "insufficient data"
**Diagnosis**: The task was querying notes from the last 24 hours instead of the last 7 days
**Root cause**: A timestamp calculation used `date -d "1 day ago"` when it should have been `date -d "7 days ago"`. The code had an off-by-one in the wrong direction.
**Fix**: Fixed the date calculation, added a check: if fewer than 10 notes found, warn and expand window
**Result**: Task now sees 7x more data, score jumped from 5/10 to 8/10

### Example 4: The Token Drain

**Task**: `auto-implement` (applies planned improvements)
**Symptom**: Daily token budget exhausted by 03:00, other tasks skipped
**Diagnosis**: auto-implement was running with no output cap, generating full implementations for tasks that were already complete
**Root cause**: The task dependency map was stale — completed tasks weren't being marked done
**Fix**: Added a dependency check at the start of auto-implement, skip tasks already marked complete
**Result**: Token usage dropped 88%, all other tasks now run as scheduled

### Example 5: The 85% Input Loss

**Task**: `knowledge-engine` (processes new notes into structured knowledge)
**Symptom**: Score declining week over week, backlog growing
**Diagnosis**: Processing pipeline was filtering notes by a `status: queued` front matter field
**Root cause**: New notes weren't being created with that field — they defaulted to no status, and the filter treated missing as "not queued"
**Fix**: Changed filter logic: treat missing status as "queued" (opt-out instead of opt-in)
**Result**: Processing rate jumped from ~15% to ~100% of new notes

---

## Scripts Reference

### `quality-triage.sh`

Scans quality scores and reports failing tasks.

```bash
bash scripts/quality-triage.sh                  # report failing tasks
bash scripts/quality-triage.sh --threshold 6.5  # custom threshold
bash scripts/quality-triage.sh --window 5       # use 5-run rolling average
bash scripts/quality-triage.sh --json           # machine-readable output
```

### `auto-fix.sh`

Applies template fixes for known failure patterns.

```bash
bash scripts/auto-fix.sh                        # fix all known patterns
bash scripts/auto-fix.sh --dry-run              # show what would change
bash scripts/auto-fix.sh --pattern wrong-model  # apply one pattern type
bash scripts/auto-fix.sh --task blog-writer     # target one task
```

### `experiment-runner.sh`

Works through the experiment queue.

```bash
bash scripts/experiment-runner.sh               # run next pending experiment
bash scripts/experiment-runner.sh --all         # run all pending experiments
bash scripts/experiment-runner.sh --status      # show queue status
```

### `experiment-queue-seeder.sh`

Adds new experiments to the queue based on current failures.

```bash
bash scripts/experiment-queue-seeder.sh         # seed from failing tasks
bash scripts/experiment-queue-seeder.sh --task knowledge-analyst  # target one task
```

---

## Patterns

ClaudeSearch ships with 10 common failure patterns that cover the majority of issues found in practice. See `patterns/failure-patterns.md` for the full list.

Quick reference:

| Pattern                  | Symptom                                  | Fix                                           |
| ------------------------ | ---------------------------------------- | --------------------------------------------- |
| `wrong-model`            | Output style doesn't match task          | Update model in task config                   |
| `stale-example`          | Output copies the example                | Separate examples from instructions           |
| `data-window-too-narrow` | "Insufficient data" warnings             | Expand query window or add fallback           |
| `missing-dependency`     | Tasks run on stale inputs                | Add dependency check at task start            |
| `opt-in-filter`          | Low processing rates                     | Switch to opt-out (treat missing as included) |
| `unbounded-output`       | Token budget exhausted                   | Add output cap to generative tasks            |
| `silent-fail`            | Task reports success but output is empty | Add output validation before marking done     |
| `config-drift`           | Works in dev, breaks in prod             | Add config snapshot to verification           |
| `prompt-creep`           | Task scope expanding, quality declining  | Refactor prompt, split task if needed         |
| `cascade-failure`        | Multiple tasks failing at once           | Check for shared upstream dependency          |

---

## Contributing

### Adding Failure Patterns

Found a new failure pattern that isn't in the list? Add it to `patterns/failure-patterns.md`:

```markdown
## Pattern: your-pattern-name

**Symptom**: What you observe in quality scores or task output
**Root cause**: The underlying cause
**Detection**: How to identify it automatically
**Fix template**: The standard fix
**Prevention**: How to avoid it in the future
**Examples**: Real instances (anonymized)
```

Open a PR with your pattern. Include at least one real example.

### Adding CLI Support

Want to add support for a new AI CLI? Create:

1. `.{cli-name}/AGENTS.md` — Instructions in the CLI's expected format
2. `docs/cli-compatibility.md` entry — Setup guide for the CLI
3. Test it end-to-end on a real project

The core loop doesn't change — only the format of the instructions.

### Sharing Experiment Results

If you run experiments and find interesting model routing results (e.g., "for Python code review, model X consistently beats model Y by 1.5 quality points"), share them:

1. Add to `docs/examples.md` with your setup details
2. Open a PR — community knowledge about model routing is valuable

### Issues and Discussions

- **Bug reports**: Use GitHub Issues with the `bug` label
- **Feature requests**: Use GitHub Discussions
- **General questions**: Use GitHub Discussions
- **Research/experiments**: Open a Discussion in the `experiments` category

---

## Philosophy

See `docs/philosophy.md` for the full write-up. Short version:

Your project's infrastructure is a model. It has parameters (configs, scripts, prompts), it has performance metrics (quality scores, success rates), and it responds to gradient descent (systematic improvement cycles). The difference from a neural network is that the parameters are human-readable and the gradients are natural language — which means you can inspect and understand every step.

This makes ClaudeSearch fundamentally different from black-box optimization. You're not tuning hyperparameters blindly — you're reading root-cause analyses in plain English and choosing whether to apply the suggested fix. The autonomy is in the loop, not in the decisions. You can always inspect, override, or learn from what the system finds.

---

## License

MIT — see LICENSE file.

---

_ClaudeSearch grew out of a real session where autonomous agents fixed 102 things in one night. The system described here is what made that possible, packaged so anyone can use it._
