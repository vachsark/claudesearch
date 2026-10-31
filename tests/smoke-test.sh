#!/usr/bin/env bash
# Smoke test for install.sh and the shipped templates.
# Usage: bash tests/smoke-test.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "ok - $*"; }

# A fake `claude` on PATH exercises the Claude Code branch; a PATH without it
# exercises the generic branch. Only the core utilities install.sh needs are linked.
FAKE_BIN="$WORK/bin-claude"
BASE_BIN="$WORK/bin-base"
mkdir -p "$FAKE_BIN" "$BASE_BIN"
for tool in bash mkdir touch cp dirname; do
    ln -s "$(command -v "$tool")" "$BASE_BIN/$tool"
done
printf '#!/bin/sh\nexit 0\n' > "$FAKE_BIN/claude"
chmod +x "$FAKE_BIN/claude"

# 1. Claude Code install
PATH="$FAKE_BIN:$BASE_BIN" bash "$REPO_DIR/install.sh" "$WORK/claude-proj" > "$WORK/out1"
[[ -f "$WORK/claude-proj/.claudesearch/quality-scores.tsv" ]] || fail "quality-scores.tsv not created"
[[ -f "$WORK/claude-proj/.claudesearch/prompt-results.jsonl" ]] || fail "prompt-results.jsonl not created"
cmp -s "$REPO_DIR/.claude/skills/autoresearch/SKILL.md" \
    "$WORK/claude-proj/.claude/skills/autoresearch/SKILL.md" || fail "SKILL.md not installed"
[[ "$(head -1 "$WORK/claude-proj/.claudesearch/quality-scores.tsv")" == "date|task|status|score|issue" ]] \
    || fail "quality-scores.tsv header wrong"
cmp -s "$REPO_DIR/templates/experiment-queue.jsonl" \
    "$WORK/claude-proj/.claudesearch/experiment-queue.jsonl" || fail "experiment queue not installed"
grep -Fxq "Docs: $REPO_DIR/README.md" "$WORK/out1" || fail "docs path is not absolute"
grep -Fxq "Philosophy: $REPO_DIR/docs/philosophy.md" "$WORK/out1" || fail "philosophy path is not absolute"
pass "install with Claude Code"

# 2. Re-running does not clobber existing tracking data
echo "2026-01-01|t|OK|5|x" >> "$WORK/claude-proj/.claudesearch/quality-scores.tsv"
printf '%s\n' '{"task":"existing","status":"pending","note":"keep these bytes"}' > "$WORK/claude-proj/.claudesearch/experiment-queue.jsonl"
cp "$WORK/claude-proj/.claudesearch/experiment-queue.jsonl" "$WORK/queue-before"
PATH="$FAKE_BIN:$BASE_BIN" bash "$REPO_DIR/install.sh" "$WORK/claude-proj" > /dev/null
cmp -s "$WORK/queue-before" "$WORK/claude-proj/.claudesearch/experiment-queue.jsonl" \
    || fail "re-install overwrote nonempty experiment queue"
grep -q '^2026-01-01|t|OK|5|x$' "$WORK/claude-proj/.claudesearch/quality-scores.tsv" \
    || fail "re-install overwrote quality-scores.tsv"
pass "re-install keeps existing data"

# 3. No supported CLI detected
PATH="$BASE_BIN" bash "$REPO_DIR/install.sh" "$WORK/plain-proj" > "$WORK/out3"
[[ -f "$WORK/plain-proj/.claudesearch/quality-scores.tsv" ]] || fail "tracking files missing without CLI"
[[ -f "$WORK/plain-proj/.claudesearch/experiment-queue.jsonl" ]] || fail "queue missing without CLI"
[[ ! -e "$WORK/plain-proj/.claude" ]] || fail "skill installed without Claude Code"
grep -q "SKILL.md" "$WORK/out3" || fail "generic quick start doesn't point at SKILL.md"
pass "install without a CLI"

# 4. Flags are rejected instead of being treated as a directory
if bash "$REPO_DIR/install.sh" --full > /dev/null 2>&1; then
    fail "install.sh --full should exit non-zero"
fi
[[ ! -e "--full" ]] || fail "install.sh created a --full directory"
pass "unknown flags rejected"

# 5. Templates match the documented formats
[[ "$(head -1 "$REPO_DIR/templates/quality-scores.tsv")" == "date|task|status|score|issue" ]] \
    || fail "templates/quality-scores.tsv header wrong"
awk -F'|' 'NR > 1 && (NF != 5 || $4 !~ /^[1-5]$/ || $3 !~ /^(OK|WARN|FAIL)$/) { print FILENAME ":" NR ": " $0; bad = 1 } END { exit bad }' \
    "$REPO_DIR/templates/quality-scores.tsv" || fail "templates/quality-scores.tsv has malformed rows"
for f in "$REPO_DIR"/templates/*.jsonl; do
    python3 -c 'import json, sys
for n, line in enumerate(open(sys.argv[1]), 1):
    if line.strip():
        try:
            json.loads(line)
        except ValueError as e:
            sys.exit(f"{sys.argv[1]}:{n}: {e}")' "$f" || fail "invalid JSONL in $(basename "$f")"
done
pass "templates are well-formed"

echo "All smoke tests passed."
