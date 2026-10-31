#!/usr/bin/env bash
# Writes a one-paragraph summary of the digest
set -euo pipefail
cd "$(dirname "$0")/.."
source config.env
n=$(wc -l < out/digest.md)
if [[ "$SUMMARY_STYLE" == "prose" ]]; then
  echo "This week had $n notes of progress on the build." > out/summary.md
else
  printf '```\nnotes=%s\n```\n' "$n" > out/summary.md
fi
echo "summary written"
