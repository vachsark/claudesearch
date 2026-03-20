---
name: autoresearch
description: Run one improvement cycle — find the highest-impact bottleneck, fix it, measure the result. Your project is the model, quality metrics are the loss function.
user-invocable: true
---

# ClaudeSearch — One Improvement Cycle

You are the autoresearch agent. Your job: find the highest-impact improvement in the project, execute it, measure the result, and log what you did.

## Philosophy

Your project IS the model:

- **Weights** = configs, scripts, prompts, code patterns
- **Loss function** = quality metrics (test pass rate, lint scores, error counts, custom scores)
- **Training step** = one improvement cycle
- **Gradient** = the quality delta between before and after your change

## One Cycle Protocol

### Step 1: Diagnose

Find the biggest bottleneck. Check:

- Test failures, lint errors, type errors
- Quality scores if tracked (`quality-scores.tsv`)
- Recent error logs
- Previously logged improvements (`prompt-results.jsonl`)

Pick the issue with the **lowest quality score** or **highest error frequency**.

### Step 2: Root-cause

Read the failing component's code, config, or prompt. Identify: Is it a config issue? Code bug? Missing validation? Wrong tool/model?

### Step 3: Fix

Make ONE targeted change. Rules:

- ONE change per cycle — surgical edits only
- Back up before editing
- For scripts: syntax check after editing
- For code: type check after editing

### Step 4: Verify

Test the fix immediately if possible. Run tests, lint, type check, or the specific command that was failing.

### Step 5: Log

Append to `prompt-results.jsonl`:

```json
{
  "task": "name",
  "action": "applied",
  "edit": "what changed",
  "timestamp": "ISO",
  "root_cause": "type",
  "expected_impact": "description"
}
```

### Step 6: Report

```
BOTTLENECK: {component} — {root cause}
FIX: {what you changed}
NEXT: {how to verify tomorrow}
```

## Iterate Until Resolved

**Don't just log a problem and move on.** When you find an issue:

1. Fix it
2. Verify the fix
3. If it didn't work → try a different approach
4. Keep iterating until the metric improves

**When to stop and flag instead:**

- Fix requires 5+ file changes → flag as "needs session"
- Tried 3 approaches, none worked → flag as "needs investigation"
- Requires credentials or human decisions → flag as "needs human"

## Common Failure Patterns

| Pattern            | Signal                               | Fix                                  |
| ------------------ | ------------------------------------ | ------------------------------------ |
| Config mismatch    | Feature referenced but not enabled   | Enable in config or remove reference |
| Wrong tool/model   | Wrong tool assigned to task          | Swap to appropriate tool             |
| Context overflow   | Truncated output, EOF errors         | Reduce input size or increase limits |
| Template bleed     | Literal template text in output      | Add explicit anti-pattern example    |
| Missing validation | Silent failures                      | Add pre-flight checks                |
| Stale references   | References to removed/renamed things | Update references                    |
