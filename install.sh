#!/usr/bin/env bash
# ClaudeSearch — Install Script
# Sets up the autoresearch system in your project.

set -euo pipefail

PROJECT_ROOT="${1:-.}"
if [[ "$PROJECT_ROOT" == -* ]]; then
    echo "Usage: bash install.sh [project-dir]" >&2
    echo "Unknown option: $PROJECT_ROOT (only a project directory argument is supported)" >&2
    exit 1
fi
echo "Installing ClaudeSearch in: $PROJECT_ROOT"

# Detect CLI
CLI="unknown"
if command -v claude &>/dev/null; then
    CLI="claude"
    echo "Detected: Claude Code"
elif command -v codex &>/dev/null; then
    CLI="codex"
    echo "Detected: OpenAI Codex CLI"
elif command -v gemini &>/dev/null; then
    CLI="gemini"
    echo "Detected: Google Gemini CLI"
else
    echo "No supported CLI detected. Install Claude Code, Codex, or Gemini CLI first."
    echo "ClaudeSearch files will still be created — configure your CLI manually."
fi

# Create directory structure
mkdir -p "$PROJECT_ROOT/.claudesearch"
mkdir -p "$PROJECT_ROOT/.claudesearch/reports"

# Create tracking files
if [[ ! -f "$PROJECT_ROOT/.claudesearch/quality-scores.tsv" ]]; then
    echo "date|task|status|score|issue" > "$PROJECT_ROOT/.claudesearch/quality-scores.tsv"
    echo "Created: quality-scores.tsv"
fi

if [[ ! -f "$PROJECT_ROOT/.claudesearch/prompt-results.jsonl" ]]; then
    touch "$PROJECT_ROOT/.claudesearch/prompt-results.jsonl"
    echo "Created: prompt-results.jsonl"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Copy skill for Claude Code
if [[ "$CLI" == "claude" ]]; then
    mkdir -p "$PROJECT_ROOT/.claude/skills/autoresearch"
    if [[ -f "$SCRIPT_DIR/.claude/skills/autoresearch/SKILL.md" ]]; then
        cp "$SCRIPT_DIR/.claude/skills/autoresearch/SKILL.md" "$PROJECT_ROOT/.claude/skills/autoresearch/SKILL.md"
        echo "Installed: .claude/skills/autoresearch/SKILL.md"
    fi
fi

echo ""
echo "ClaudeSearch installed!"
echo ""
echo "Quick start:"
if [[ "$CLI" == "claude" ]]; then
    echo "  cd $PROJECT_ROOT"
    echo "  claude"
    echo "  > /autoresearch"
else
    echo "  1. Add the contents of $SCRIPT_DIR/.claude/skills/autoresearch/SKILL.md to your CLI's"
    echo "     context file (AGENTS.md for Codex, GEMINI.md for Gemini CLI)"
    echo "  2. Run: 'Run one ClaudeSearch improvement cycle on this project'"
    echo "  3. Check .claudesearch/prompt-results.jsonl for logged improvements"
fi
echo ""
echo "Docs: README.md"
echo "Philosophy: docs/philosophy.md"
