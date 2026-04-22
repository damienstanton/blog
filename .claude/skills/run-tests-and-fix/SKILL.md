<!-- AUTO-GENERATED from .claude/ — do not edit directly. Run: bash .claude/scripts/sync-claude.sh -->
---
name: run-tests-and-fix
description: Run the full test suite, fix failures with user approval, and optionally run code review.
---
# Run Tests and Fix

Run the full test suite, fix any failures, and optionally run code review.

## Initial Setup

Read the active profile from `.claude/profiles/*.yaml` (skip `_template.yaml`) for toolchain and governance configuration.

## Phase 1: Run Tests

Delegate to `test-runner` (readonly):

- Run the full test suite: `{{toolchain.test_cmd_full}}`
- Parse the output per `{{toolchain.test_output_format}}`
- Treat skipped tests and SSL certificate failures as failures (per governance policy)

Present the report to the user. If all tests pass with zero skips, skip to Phase 3.

## Phase 2: Fix Failures (User-Gated)

If the test report shows failures or skips:

> **N failures detected.** Want to inspect and fix?
>
> Failures:
> 1. `test_name` — [one-line root cause]
> 2. `test_name` — [one-line root cause]
>
> Options:
> - **Yes** — Launch test-fixer to analyze and implement fixes
> - **No** — Show the full report only

If user says yes:

1. Delegate to `test-fixer` (read-write) with the failure report
2. Write fix artifacts to `.claude/artifacts/TASK-NNN_test_fix.json` and `.claude/artifacts/TASK-NNN_test_fix.md` (use `standalone` if no ticket context)
3. Present fix report showing what was fixed and what needs manual review
4. Re-run tests via `test-runner` to verify fixes
5. If still failing, inform user and offer to iterate or stop

## Phase 3: Code Review (User-Gated)

After tests are green (or user chooses to proceed):

> **Tests are passing.** Want to run the code review cycle?
>
> This launches 8 review agents in 3 batches to check correctness, quality, documentation, error handling, ops hygiene, and test quality.

If user says yes:

### Step 1: Capture the diff

```bash
git diff
```

Write the diff to `.claude/artifacts/TASK-NNN_diff.md` (or a temp file if no ticket context).

### Step 2: Batch 1 — Correctness (parallel, blocking)

Launch all in a single message:
- `review-correctness-defensive`
- `review-correctness-specification`

Parse JSON finding arrays from their text responses.

### Step 3: Batch 2 — Quality + Docs (parallel, advisory)

After Batch 1 completes:
- `review-quality-structural`
- `review-quality-evolutionary`
- `review-docs-consistency`

Parse JSON finding arrays from their text responses.

### Step 3b: Batch 3 — Extended (parallel, advisory)

After Batch 2 completes:
- `review-error-surface`
- `review-operations-hygiene`
- `review-test-quality`

Parse JSON finding arrays from their text responses.

### Step 4: Aggregate and persist findings

Merge all findings, deduplicate by location, and write:
- `.claude/artifacts/TASK-NNN_review.json` — merged findings array
- `.claude/artifacts/TASK-NNN_review.md` — formatted summary table

Classify each finding by confidence:
- **High:** 2+ agents, OR Critical/High severity
- **Medium:** Medium severity from 1 agent
- **Low:** Low/Info from 1 agent

### Step 5: Present findings

```
## Code Review Findings

### Auto-Fix Candidates (High Confidence)
| # | Category | File | Description | Suggested Fix | Flagged By |
|---|----------|------|-------------|---------------|------------|

### For User Review (Medium/Low)
| # | Category | Severity | File | Description | Suggestion | Flagged By |
|---|----------|----------|------|-------------|------------|------------|
```

Ask user if they want to auto-fix high-confidence findings. If yes, apply the fixes, re-run tests to verify.

### Step 6: Persist for Walkthrough

Persist the findings to `.claude/state/review-findings.json` with the structure defined in `/review-findings`. Direct the user:

> Run `/review-findings` to walk through the remaining findings one-by-one.

## Final Report

```
## Session Summary

### Test Results
- Total: N | Passed: N | Failed: N | Skipped: N

### Fixes Applied
- [list of fixes, or "None needed"]

### Code Review
- [summary of findings, or "Not requested"]

### Artifacts Written
- [list of artifact files created during this session]

### Next Steps
1. Review changes with `git status` and `git diff`
2. Commit when satisfied
```
