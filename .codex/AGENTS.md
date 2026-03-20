# ClaudeSearch for OpenAI Codex CLI

ClaudeSearch works with any AI CLI that has file read/write/search capabilities. The core concept is CLI-agnostic.

## Setup

1. Copy `skills/autoresearch.md` into your Codex agent configuration
2. Create a `quality-scores.tsv` file to track metrics
3. Run the autoresearch cycle when you want to improve your project

## How It Maps

| ClaudeSearch Concept  | Codex Equivalent                            |
| --------------------- | ------------------------------------------- |
| `/autoresearch` skill | Agent with autoresearch.md as system prompt |
| Background Agent      | Codex async task                            |
| `Read` tool           | File read capability                        |
| `Edit` tool           | File edit capability                        |
| `Bash` tool           | Command execution                           |
| `WebSearch`           | Web browsing capability                     |

## Running a Cycle

```bash
codex --agent autoresearch "Run one improvement cycle on this project"
```

The agent will follow the same diagnose → root-cause → fix → verify → log protocol.

## Limitations vs Claude Code

- No native `.claude/skills/` auto-detection — load the skill manually
- No `Agent` tool for spawning sub-agents — run cycles sequentially
- No `isolation: "worktree"` — manage git branches manually for project scouts
