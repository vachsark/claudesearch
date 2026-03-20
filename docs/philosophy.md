# Philosophy: Your Project Is the Model

## The Core Idea

Karpathy's autoresearch runs 100 GPU experiments per night to improve a neural network. Each experiment changes one thing, measures the loss, and keeps or discards the change.

ClaudeSearch applies the same pattern to your **entire development infrastructure** — not just model weights, but configs, scripts, prompts, code patterns, and workflows.

## The Mapping

| Machine Learning | ClaudeSearch                                                  |
| ---------------- | ------------------------------------------------------------- |
| Model weights    | Configs, scripts, prompts, code                               |
| Training data    | Your codebase, docs, task outputs                             |
| Loss function    | Quality metrics (test pass rate, error counts, custom scores) |
| Gradient step    | One improvement cycle (diagnose → fix → verify)               |
| Learning rate    | How aggressive the changes are                                |
| Overfitting      | Fixing one thing while breaking another                       |
| Early stopping   | Stopping when quality targets are met                         |

## Why It Works

Most development infrastructure accumulates **silent failures** — things that technically "work" but produce suboptimal output:

- A config that references a removed feature
- A script that reads stale data
- A prompt that was great when written but drifted as the system evolved
- A tool assigned to a task it's not suited for

These failures are invisible because:

1. The system doesn't crash — it just produces worse output
2. No one is systematically measuring output quality
3. No one is looking at the system holistically (individual components look fine)

ClaudeSearch makes these visible by:

1. **Tracking quality metrics** in a simple TSV file
2. **Running systematic audits** via AI agents
3. **Following a pattern table** of known failure modes
4. **Iterating until resolved** — not just reporting, but fixing

## The Compound Effect

Each fix improves the system's ability to find the next fix:

- Cleaner data → better quality scores → more accurate triage → better fixes
- Fixed dependencies → downstream tasks improve → cascade of quality gains
- Pattern table grows → future audits are faster → more issues caught per cycle

This is the same compound effect that makes neural network training work — each gradient step makes the next step more effective.

## When to Use ClaudeSearch

- **After shipping features**: Run a cycle to catch regressions
- **On a schedule**: Daily or weekly automated cycles
- **When quality drops**: The triage system detects it and triggers a cycle
- **When onboarding**: Run a full audit on a new project
- **When curious**: "What's the weakest part of this system?"

## When NOT to Use ClaudeSearch

- Don't run on code you haven't committed (make it reversible first)
- Don't auto-fix things that require business decisions
- Don't optimize prematurely — focus on broken things before improving working things
- Don't run during active development on the same files (coordinate first)
