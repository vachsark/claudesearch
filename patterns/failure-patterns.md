# Common Failure Patterns

These 10 patterns account for ~80% of issues found during ClaudeSearch cycles. Check these first before investigating deeper.

| #   | Pattern                     | Signal                                                        | Fix                                                            | Auto-fixable?       |
| --- | --------------------------- | ------------------------------------------------------------- | -------------------------------------------------------------- | ------------------- |
| 1   | **Config mismatch**         | Feature referenced in code but not enabled in config          | Enable in config or remove the reference                       | Yes (mechanical)    |
| 2   | **Wrong tool/model**        | Code model assigned to prose task, or vice versa              | Swap to appropriate tool for the domain                        | No (judgment)       |
| 3   | **Context overflow**        | `unexpected EOF`, truncated output, exact token limit in logs | Reduce input size, raise context limit, or paginate            | Yes (raise limit)   |
| 4   | **Template bleed**          | Literal template/placeholder text appears in output           | Add explicit anti-pattern example showing what NOT to output   | No (prompt edit)    |
| 5   | **Stale reference**         | Config references a renamed/removed/archived component        | Update reference to current name/path                          | Yes (mechanical)    |
| 6   | **Token budget exhaustion** | Output cuts off mid-sentence or mid-section                   | Raise output token limit in config                             | Yes (raise limit)   |
| 7   | **Missing postprocessor**   | Structured output markers in logs but no files written        | Create the missing output handler                              | No (new code)       |
| 8   | **Silent skip**             | Task completes "successfully" but produces no useful output   | Check input validation — data may be silently filtered         | No (investigation)  |
| 9   | **Stale data in scoring**   | Quality scores reflect old issues that were already fixed     | Check if the scorer reads from the correct/current data source | No (data source)    |
| 10  | **Cascade failure**         | One broken task causes downstream tasks to fail/degrade       | Trace the dependency chain, fix the upstream task first        | No (chain analysis) |

## How to Use This Table

During Step 2 (Root-cause) of a ClaudeSearch cycle:

1. Read the failing component's recent output
2. Match the symptoms against the Signal column
3. Apply the Fix column's recommendation
4. If auto-fixable, apply immediately. If not, diagnose deeper.

## Adding New Patterns

When you find a failure pattern that appears 3+ times:

1. Add it to this table
2. Include the Signal (how to detect it) and Fix (how to resolve it)
3. Mark whether it's auto-fixable (mechanical change) or requires judgment
