#!/usr/bin/env bash
# Collects notes from the last DIGEST_WINDOW_DAYS days into out/digest.md
set -euo pipefail
cd "$(dirname "$0")/.."
source config.env
TODAY="${TODAY:-$(date +%F)}"
cutoff=$(date -d "$TODAY -1 day" +%F)
: > out/digest.md
count=0
for f in data/notes/*.md; do
  d=$(basename "$f" | cut -c1-10)
  if [[ "$d" > "$cutoff" || "$d" == "$cutoff" ]]; then
    tail -n 1 "$f" >> out/digest.md; count=$((count+1))
  fi
done
echo "digest: $count notes"
