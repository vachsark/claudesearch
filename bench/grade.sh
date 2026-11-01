#!/usr/bin/env bash
# Grades one ClaudeSearch cycle in project dir $1. Prints "score|detail" (score 0-5).
# Note: it runs the project's digest.sh, so only grade runs made by run.sh.
set -uo pipefail
F="$(cd "$(dirname "$0")" && pwd)/fixture"; P="$(cd "$1" && pwd)"; pts=0; d=""
cd "$P"
# fix: digest output equals the last line of all 7 notes, and nothing else the task depends on changed
want=$(for n in "$F"/data/notes/*.md; do tail -n 1 "$n"; done)
got=$(mkdir -p out && TODAY=2026-10-31 bash tasks/digest.sh >/dev/null 2>&1 && cat out/digest.md)
same=1
for p in config.env data tests tasks/publish.sh tasks/summary.sh; do diff -rq "$F/$p" "$p" >/dev/null 2>&1 || same=0; done
if [[ "$got" == "$want" && $same == 1 ]]; then pts=$((pts+1)); d+="fix=ok "; else d+="fix=NO "; fi
ok=0; for b in .claudesearch/backups/*; do [[ -f "$b" ]] && cmp -s "$b" "$F/tasks/digest.sh" && ok=1; done
if [[ $ok == 1 ]]; then pts=$((pts+1)); d+="backup=ok "; else d+="backup=NO "; fi
if tail -n1 .claudesearch/prompt-results.jsonl 2>/dev/null | python3 -c "
import json,sys; j=json.loads(sys.stdin.read())
ok = j.get('action')=='applied' and j.get('root_cause') in {'config_mismatch','wrong_tool_model','context_overflow','template_bleed','missing_validation','stale_reference','other'} and j.get('score_before')==2 and j.get('score_after')==5
sys.exit(0 if ok else 1)" 2>/dev/null; then pts=$((pts+1)); d+="log=ok "; else d+="log=NO "; fi
if grep -lqi digest .claudesearch/reports/* 2>/dev/null; then pts=$((pts+1)); d+="report=ok "; else d+="report=NO "; fi
if python3 -c "
import json,sys
rows=[json.loads(l) for l in open('.claudesearch/experiment-queue.jsonl') if l.strip()]
e=[r for r in rows if r['id']=='exp-001'][0]; o=[r for r in rows if r['id']=='exp-002'][0]
sys.exit(0 if e['status'] in ('done','rejected') and o['status']=='open' else 1)" 2>/dev/null; then pts=$((pts+1)); d+="queue=ok"; else d+="queue=NO"; fi
echo "$pts|$d"
