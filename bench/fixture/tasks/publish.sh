#!/usr/bin/env bash
# Publishes every note that is ready. Notes are ready unless marked status: draft.
set -euo pipefail
cd "$(dirname "$0")/.."
: > out/published.txt
for f in data/notes/*.md; do
  if grep -q '^status: queued' "$f"; then
    basename "$f" >> out/published.txt
  fi
done
echo "published: $(wc -l < out/published.txt)"
