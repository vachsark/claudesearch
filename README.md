# ClaudeSearch

**Your project is the model. Quality scores are the loss. Each improvement cycle is a training step.**

ClaudeSearch is a Claude Code skill that runs one improvement cycle on a project: find the weakest part, find the root cause, make one fix, check that it worked, and log it. Run it by hand, on a schedule, or as many agents in parallel.

It grew out of my own setup, where it has run for weeks:

- **163 code improvements** logged, each passed by a quality gate, averaging **4.28 / 5**
- **6,000+ knowledge notes** written by a local model at 149 tok/s, at no API cost
- **5 feature specs** written for my production app from those notes, kept suggest-only for human review

The idea comes from Karpathy's [autoresearch](https://github.com/karpathy/autoresearch), which trains neural networks autonomously. ClaudeSearch applies the same loop to the scripts, prompts and configs around your code.

---

## What's in this repo

| Path | What it is |
| --- | --- |
| `.claude/skills/autoresearch/SKILL.md` | The skill. Run `/autoresearch` in Claude Code |
| `.codex/AGENTS.md`, `.gemini/AGENTS.md` | Setup notes for Codex CLI and Gemini CLI |
| `patterns/failure-patterns.md` | 10 failure patterns to check first |
| `templates/` | Starter `quality-scores.tsv`, `prompt-results.jsonl` and `experiment-queue.jsonl` |
| `install.sh` | Copies the skill and creates the tracking files in your project |
| `docs/philosophy.md` | Why "your project is the model" works |
| `tests/smoke-test.sh` | Checks `install.sh` and the templates; CI runs it with shellcheck |
| `docs/v4-architecture.md` | How the full two-instance loop runs on my machine (its loop scripts are not included) |

## Quick start

```bash
git clone https://github.com/vachsark/claudesearch
cd your-project
bash /path/to/claudesearch/install.sh
claude    # then type: /autoresearch
```

`install.sh` creates `.claudesearch/quality-scores.tsv` and `.claudesearch/prompt-results.jsonl` and, if it finds Claude Code, installs the skill. Add a few recent scores for your automated tasks to `quality-scores.tsv`; 3 or 4 per task is enough to start. On the first run, watch what it finds before you let it apply fixes.

**Codex or Gemini CLI:** they read `AGENTS.md` or `GEMINI.md` at your project root, so append the skill there. The `awk` skips the YAML frontmatter, which only Claude Code uses.

```bash
awk 'f; /^---$/ && ++n==2 {f=1}' claudesearch/.claude/skills/autoresearch/SKILL.md >> your-project/AGENTS.md   # Codex
awk 'f; /^---$/ && ++n==2 {f=1}' claudesearch/.claude/skills/autoresearch/SKILL.md >> your-project/GEMINI.md   # Gemini
codex "run one ClaudeSearch improvement cycle on this project"
```

**Any other CLI with file and shell access** can run the same loop from a plain prompt: read `.claudesearch/quality-scores.tsv`, find tasks averaging below 3.5 over 3+ runs, root-cause and fix one, rerun it, and log the change to `.claudesearch/prompt-results.jsonl`.

## The cycle

```
diagnose → root-cause → fix (one change) → verify → log → repeat
```

1. **Diagnose:** find the lowest quality score or the most frequent error.
2. **Root-cause:** read the failing component's code, config or prompt. Is it a config issue, a bug, a missing check, or the wrong model?
3. **Fix:** make one targeted change. Back up first, then syntax or type check.
4. **Verify:** run the test or the failing command again.
5. **Log:** append what changed and why to `prompt-results.jsonl`.

It stops and flags instead of fixing when a change needs 5+ files, when 3 approaches have failed, or when it needs credentials or a human decision.

## Quality scores

One line per task run, pipe-delimited, scored 1 to 5 with a status of OK, WARN or FAIL. A task whose rolling average drops below 3.5 is a candidate for the next cycle.

```
date|task|status|score|issue
2026-03-19|blog-writer|WARN|3|Word count too low (241 words) — triggers publisher gate
2026-03-19|knowledge-spacer|OK|4|Scores calibrated, no meta-commentary
2026-03-19|morning-briefing|OK|5|Clean output, no template bleed
```

## Failure patterns

The 10 patterns in `patterns/failure-patterns.md`, checked before deeper investigation:

| # | Pattern | Signal |
| --- | --- | --- |
| 1 | Config mismatch | Feature referenced in code but not enabled in config |
| 2 | Wrong tool/model | Code model assigned to a prose task, or the reverse |
| 3 | Context overflow | `unexpected EOF`, truncated output |
| 4 | Template bleed | Placeholder text appears in output |
| 5 | Stale reference | Config points at a renamed or removed component |
| 6 | Token budget exhaustion | Output cuts off mid-sentence |
| 7 | Missing postprocessor | Structured output in logs but no files written |
| 8 | Silent skip | Task "succeeds" but produces nothing useful |
| 9 | Stale data in scoring | Scores reflect issues already fixed |
| 10 | Cascade failure | One broken task degrades the ones after it |

## Real fixes from my setup

These runs predate the 1 to 5 scale, so their scores are out of 10.

- **Silent copy bug:** `session-reflection` scored 4/10 six runs in a row because the agent copied the prompt's example verbatim. Separating the example took 2 minutes and the score went to 8/10.
- **Wrong model:** `blog-writer` had been switched to a code model during debugging. Switching back got the blog publishing again after 9 days broken.
- **Data window:** `knowledge-analyst` read 1 day of notes instead of 7. Fixing the date math gave it 7x the data, and its score went from 5/10 to 8/10.
- **Token drain:** `auto-implement` re-did finished tasks and used up the daily budget by 03:00. A dependency check cut its token use by 88%.
- **Opt-in filter:** new notes were skipped because they had no `status` field. Treating missing as "queued" took processing from ~15% to ~100% of new notes.

## The full loop on my machine

On my own setup two instances run side by side. A local MoE model on the GPU researches and writes knowledge notes for free, about 510 cycles an hour. Claude reads the best notes, looks for a real mismatch in code, and implements only changes it scores 4/5 or higher, about 6 cycles an hour. My production app is suggest-only: changes there go to a file for my review. Details are in [docs/v4-architecture.md](docs/v4-architecture.md).

## Contributing

Run `bash tests/smoke-test.sh` and `shellcheck install.sh` before opening a PR; CI runs both. New failure patterns go in `patterns/failure-patterns.md` with at least one real example. [docs/philosophy.md](docs/philosophy.md) explains the thinking behind the loop.

## License

MIT, see [LICENSE](LICENSE).
