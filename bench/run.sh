#!/usr/bin/env bash
# run.sh <label> [skill-file]: fresh copy of the fixture, install skill, seed, run one headless cycle, grade.
B="$(cd "$(dirname "$0")" && pwd)"; SKILL="${2:-$B/../.claude/skills/autoresearch/SKILL.md}"; W="$B/runs/$1"; rm -rf "$W"; mkdir -p "$B/runs"; cp -r "$B/fixture" "$W"; cd "$W"
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
timeout 900 claude -p "/autoresearch" --permission-mode acceptEdits --allowedTools "Bash(bash:*) Bash(cat:*) Bash(date:*) Bash(cp:*) Bash(mkdir:*) Bash(grep:*) Bash(ls:*) Bash(wc:*) Bash(echo:*) Bash(git diff:*) Bash(git status:*) Read Edit Write Glob Grep" --max-turns 50 > "$B/runs/$1.out" 2>&1
echo "$1|$(bash "$B/grade.sh" "$W")" >> "$B/results.txt"
