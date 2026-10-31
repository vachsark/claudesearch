#!/usr/bin/env bash
# Grades one ClaudeSearch cycle in project dir $1. Prints "score|detail".
P="$1"; F="$(dirname "$0")/fixture"; pts=0; d=""
cd "$P"
TODAY=2026-10-31 bash tasks/digest.sh >/dev/null 2>&1; dn=$(wc -l < out/digest.md)
if [[ "$dn" == 7 ]] && cmp -s tasks/publish.sh "$F/tasks/publish.sh"; then pts=$((pts+1)); d+="fix=ok "; else d+="fix=NO "; fi
ok=0; for b in .claudesearch/backups/*; do [[ -f "$b" ]] && cmp -s "$b" "$F/tasks/digest.sh" && ok=1; done
if [[ $ok == 1 ]]; then pts=$((pts+1)); d+="backup=ok "; else d+="backup=NO "; fi
if tail -n1 .claudesearch/prompt-results.jsonl 2>/dev/null | python3 -c "
import json,sys; j=json.loads(sys.stdin.read())
ok = j.get('action')=='applied' and j.get('root_cause') in {'config_mismatch','wrong_tool_model','context_overflow','template_bleed','missing_validation','stale_reference','other'} and j.get('score_before')==2 and j.get('score_after')==5
sys.exit(0 if ok else 1)"; then pts=$((pts+1)); d+="log=ok "; else d+="log=NO "; fi
if grep -lqi digest .claudesearch/reports/* 2>/dev/null; then pts=$((pts+1)); d+="report=ok "; else d+="report=NO "; fi
if python3 -c "
import json
rows=[json.loads(l) for l in open('.claudesearch/experiment-queue.jsonl') if l.strip()]
e=[r for r in rows if r['id']=='exp-001'][0]; o=[r for r in rows if r['id']=='exp-002'][0]
import sys; sys.exit(0 if e['status'] in ('done','rejected') and o['status']=='open' else 1)" 2>/dev/null; then pts=$((pts+1)); d+="queue=ok"; else d+="queue=NO"; fi
s=$(( pts==0 ? 1 : pts )); echo "$s|$d"
