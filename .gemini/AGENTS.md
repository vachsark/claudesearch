# ClaudeSearch for Google Gemini CLI

ClaudeSearch is CLI-agnostic. The diagnose → fix → verify cycle works with any AI tool that can read files, edit code, and run commands.

## Setup

1. Copy `skills/autoresearch.md` into your Gemini agent/prompt configuration
2. Create a `quality-scores.tsv` file to track metrics
3. Run improvement cycles through Gemini's task system

## How It Maps

| ClaudeSearch Concept  | Gemini Equivalent                          |
| --------------------- | ------------------------------------------ |
| `/autoresearch` skill | System prompt with autoresearch.md content |
| Background Agent      | Gemini async task                          |
| Quality scores        | Same TSV format — CLI-agnostic             |
| Improvement log       | Same JSONL format — CLI-agnostic           |

## Running a Cycle

Load the autoresearch skill content as a system prompt, then:

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
