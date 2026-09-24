# ClaudeSearch for Google Gemini CLI

ClaudeSearch is CLI-agnostic. The diagnose → fix → verify cycle works with any AI tool that can read files, edit code, and run commands.

## Setup

1. Copy the contents of `.claude/skills/autoresearch/SKILL.md` into a `GEMINI.md` file at your project root (Gemini CLI loads `GEMINI.md` by default, not `AGENTS.md`; to use `AGENTS.md` instead, set `"context": {"fileName": ["AGENTS.md", "GEMINI.md"]}` in `.gemini/settings.json`)
2. Create a `quality-scores.tsv` file to track metrics
3. Run improvement cycles through Gemini's task system

## How It Maps

| ClaudeSearch Concept  | Gemini Equivalent                          |
| --------------------- | ------------------------------------------ |
| `/autoresearch` skill | Autoresearch protocol in `GEMINI.md`       |
| Background Agent      | Gemini async task                          |
| Quality scores        | Same TSV format — CLI-agnostic             |
| Improvement log       | Same JSONL format — CLI-agnostic           |

## Running a Cycle

With the protocol in `GEMINI.md`, start `gemini` in your project and prompt (or, for headless mode, `gemini --approval-mode auto_edit -p "..."` so edits are auto-approved):

```
Run one ClaudeSearch improvement cycle on this project.
Read quality-scores.tsv for the current state, find the worst-performing area,
diagnose the root cause, fix it, verify, and log the result.
```

## What Works Everywhere

The core ClaudeSearch value is the PROCESS, not the tooling:

1. Track quality metrics in a simple TSV
2. Log improvements in JSONL
3. Follow the pattern table for common failures
4. Iterate until resolved, don't just report

These files are plain text — they work with any AI assistant.
