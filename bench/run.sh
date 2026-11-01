#!/usr/bin/env bash
# run.sh <label> [skill-file]: fresh copy of the fixture, install skill, seed, run one headless cycle, grade.
set -euo pipefail
label="${1:-}"
if [[ ! "$label" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "usage: run.sh <label> [skill-file]  (label: letters, digits, . _ - only)" >&2; exit 2
fi
if [[ "$(uname)" == Linux ]] && ! { command -v bwrap && command -v socat; } >/dev/null; then
  echo "run.sh: install bubblewrap and socat first (the child run is sandboxed with them)" >&2; exit 3
fi
B="$(cd "$(dirname "$0")" && pwd)"; SKILL="$(realpath "${2:-$B/../.claude/skills/autoresearch/SKILL.md}")"
W="$B/runs/$label"; rm -rf -- "$W"; mkdir -p "$B/runs"; cp -r "$B/fixture" "$W"; cd "$W"
mkdir -p out .claude/skills/autoresearch .claudesearch/reports .claudesearch/backups
cp "$SKILL" .claude/skills/autoresearch/SKILL.md
echo "date|task|status|score|issue" > .claudesearch/quality-scores.tsv
cat >> .claudesearch/quality-scores.tsv <<'R'
2026-10-28|digest|FAIL|2|2 of 7 notes in window
2026-10-28|publish|WARN|3|4 of 7 ready notes published
2026-10-28|summary|OK|5|summary style check
2026-10-31|digest|FAIL|2|2 of 7 notes in window
2026-10-31|publish|WARN|3|4 of 7 ready notes published
2026-10-31|summary|OK|5|summary style check
R
touch .claudesearch/prompt-results.jsonl; mv experiment-queue.seed .claudesearch/experiment-queue.jsonl
git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm base
# The child run's shell commands go through Claude Code's OS sandbox: writes only inside this run
# folder (and Claude's temp dir), no network, no MCP servers, no web tools. File tools are scoped
# to this folder too. On Linux the sandbox needs bubblewrap and socat.
sandbox='{"sandbox":{"enabled":true,"autoAllowBashIfSandboxed":true,"allowUnsandboxedCommands":false}}'
timeout 900 claude -p "/autoresearch" --permission-mode default --strict-mcp-config --settings "$sandbox" \
  --allowedTools "Read(./**)" "Edit(./**)" "Glob" "Grep" --disallowedTools WebFetch WebSearch Task \
  --max-turns 50 > "$B/runs/$label.out" 2>&1 || true
echo "$label|$(bash "$B/grade.sh" "$W")" >> "$B/results.txt"
