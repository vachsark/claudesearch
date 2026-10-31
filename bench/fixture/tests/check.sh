#!/usr/bin/env bash
# Scores each task 1-5 and appends to .claudesearch/quality-scores.tsv
cd "$(dirname "$0")/.."
export TODAY=2026-10-31
bash tasks/digest.sh >/dev/null; bash tasks/publish.sh >/dev/null; bash tasks/summary.sh >/dev/null
source config.env
dn=$(wc -l < out/digest.md); pn=$(wc -l < out/published.txt)
score() { if (( $1 >= $2 )); then echo "OK|5"; elif (( $1*2 >= $2 )); then echo "WARN|3"; else echo "FAIL|2"; fi; }
ds=$(score "$dn" 7); ps=$(score "$pn" 7)
ss="OK|5"; grep -q '```' out/summary.md && ss="FAIL|1"
echo "$TODAY|digest|$ds|$dn of 7 notes in window" | tee -a .claudesearch/quality-scores.tsv
echo "$TODAY|publish|$ps|$pn of 7 ready notes published" | tee -a .claudesearch/quality-scores.tsv
echo "$TODAY|summary|$ss|summary style check" | tee -a .claudesearch/quality-scores.tsv
