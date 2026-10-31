# ClaudeSearch for OpenAI Codex CLI

ClaudeSearch works with any AI CLI that has file read/write/search capabilities. The core concept is CLI-agnostic.

## Setup

1. Copy the contents of `.claude/skills/autoresearch/SKILL.md` into an `AGENTS.md` file at your project root (Codex reads `AGENTS.md` from the repo root down to the working directory, plus the global `~/.codex/AGENTS.md` — it does not read `.codex/AGENTS.md` inside a project)
2. Run `install.sh` (or create `.claudesearch/quality-scores.tsv` yourself) to track metrics — pipe-delimited `date|task|status|score|issue`, scores 1-5
3. Run the autoresearch cycle when you want to improve your project

## How It Maps

| ClaudeSearch Concept  | Codex Equivalent                            |
| --------------------- | ------------------------------------------- |
| `/autoresearch` skill | Autoresearch protocol in `AGENTS.md`        |
| Background Agent      | Codex async task                            |
| `Read` tool           | File read capability                        |
| `Edit` tool           | File edit capability                        |
| `Bash` tool           | Command execution                           |
| `WebSearch`           | Web browsing capability                     |

## Running a Cycle

```bash
# Interactive
codex "Run one ClaudeSearch improvement cycle on this project"

# Non-interactive (workspace-write lets it apply fixes)
codex exec --sandbox workspace-write "Run one ClaudeSearch improvement cycle on this project"
```

The agent will follow the same diagnose → root-cause → fix → verify → log protocol.

## Limitations vs Claude Code

- No native `.claude/skills/` auto-detection — load the skill manually
- No `Agent` tool for spawning sub-agents — run cycles sequentially
- No `isolation: "worktree"` — manage git branches manually for project scouts
