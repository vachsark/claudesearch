# Benchmark: ClaudeSearch grading itself

A small newsletter pipeline (`fixture/`) with three scheduled tasks. `digest.sh` has a planted bug (it reads 1 day of notes though `config.env` says 7) and scores 2. `publish.sh` scores 3 and `summary.sh` scores 5.

`run.sh <label> [skill-file]` copies the fixture to `runs/<label>`, installs the skill, seeds the scores and an experiment queue, runs one headless `claude -p /autoresearch` cycle, and grades it with `grade.sh`. Each of the five checks is one point:

- **fix:** digest now reads all 7 notes, and `publish.sh` is untouched (one change per cycle)
- **backup:** a copy of the original `digest.sh` is inside `.claudesearch/backups/`
- **log:** the log line has `action`, a known `root_cause`, and `score_before` 2 → `score_after` 5
- **report:** the cycle's report is saved in `.claudesearch/reports/`
- **queue:** the digest experiment is closed and the publish one is still open

```bash
for i in 1 2 3; do bash bench/run.sh run-$i & done; wait; cat bench/results.txt
```

Needs Claude Code signed in. Each run costs one cycle of model usage. `runs/` and `results.txt` are git-ignored.
