<!-- AUTO-GENERATED from .claude/ — do not edit directly. Run: bash .claude/scripts/sync-claude.sh -->
---
name: review-code
description: Run the 8-agent code review on the current diff without requiring a ticket.
---
# Code Review

Run the 8-agent code review on the current diff. No ticket required.

## When to Use

- Reviewing changes before committing
- Spot-checking code quality on a branch
- Auditing a colleague's PR locally
- Running a quality gate outside the full implementation workflow

## Initial Setup

Read the active profile from `.claude/profiles/*.yaml` (skip `_template.yaml`) for language context and review graph configuration.

## Phase 1: Capture the Diff

Determine what to review. Ask the user if unclear:

| User says | Action |
|-----------|--------|
| "Review this diff" / no qualifier | `git diff` (unstaged changes) |
| "Review staged changes" | `git diff --cached` |
| "Review this branch" | `git diff main...HEAD` (or appropriate base branch) |
| "Review the last N commits" | `git diff HEAD~N...HEAD` |
| "Review this file" / `@path` | `git diff -- <path>` |

If the diff is empty, inform the user and stop:

> No changes detected. Make sure you have uncommitted changes, or specify a branch/commit range.

Write the diff to `.claude/artifacts/standalone_review_diff.md`.

## Phase 2: Run Review (8 Agents, 3 Batches)

### Batch 1 — Correctness (parallel, blocking)

Launch both in a single message:
- `review-correctness-defensive` — Runtime bugs, null risks, panics, resource leaks
- `review-correctness-specification` — Contract violations, edge cases, error handling gaps

Parse JSON finding arrays from their text responses.

If any **critical** or **high** severity findings exist, flag them prominently before continuing.

### Batch 2 — Quality + Docs (parallel, advisory)

After Batch 1 completes, launch all three:
- `review-quality-structural` — Naming, complexity, duplication, nesting
- `review-quality-evolutionary` — Tech debt, coupling, test coverage, breaking changes
- `review-docs-consistency` — Docstrings, README accuracy, missing documentation

Parse JSON finding arrays from their text responses.

### Batch 3 — Extended (parallel, advisory)

After Batch 2 completes, launch all three:
- `review-error-surface` — Error handling completeness, error message clarity
- `review-operations-hygiene` — Logging consistency, hardcoded config, magic constants
- `review-test-quality` — Test assertions, isolation, coverage strategy

Parse JSON finding arrays from their text responses.

## Phase 3: Aggregate Findings

1. Merge all findings from both batches
2. Deduplicate by file + line range (keep highest severity)
3. Classify by confidence:
   - **High confidence:** 2+ agents flagged, OR Critical/High severity from any agent
   - **Medium confidence:** Medium severity from 1 agent
   - **Low confidence:** Low/Info from 1 agent

Write results to:
- `.claude/artifacts/standalone_review.json`
- `.claude/artifacts/standalone_review.md`

## Phase 4: Present Results

```
## Code Review Results

**Diff scope:** [description of what was reviewed]
**Agents:** 8 (Correctness x2, Quality x2, Docs, Error Surface, Ops Hygiene, Test Quality)
**Findings:** N total (X high, Y medium, Z low)

### Critical / High Findings (Action Required)
| # | Category | Severity | File:Line | Description | Suggested Fix |
|---|----------|----------|-----------|-------------|---------------|

### Medium Findings (Recommended)
| # | Category | File:Line | Description | Suggestion |
|---|----------|-----------|-------------|------------|

### Low / Info (Optional)
| # | Category | File:Line | Description |
|---|----------|-----------|-------------|

### Summary by Lens
| Lens | Findings | Top Category |
|------|----------|--------------|
| Correctness (Defensive) | N | ... |
| Correctness (Specification) | N | ... |
| Quality (Structural) | N | ... |
| Quality (Evolutionary) | N | ... |
| Documentation | N | ... |
| Error Surface | N | ... |
| Operations Hygiene | N | ... |
| Test Quality | N | ... |
```

## Phase 5: Optional Auto-Fix

If any high-confidence findings have `auto_fixable: true`:

> **N findings are auto-fixable** with high confidence and low risk.
> Want me to apply them? (I'll re-run tests afterward to verify.)

If user says yes:
1. Apply each fix
2. Run `{{toolchain.test_cmd_full}}` to verify nothing broke
3. Present what was fixed and confirm tests still pass
4. If any test breaks after a fix, revert that fix and report it

## Phase 6: Persist Findings for Walkthrough

After presenting results and applying any auto-fixes, persist the remaining findings to `.claude/state/review-findings.json`:

```json
{
  "timestamp": "ISO-8601",
  "diff_scope": "description of what was reviewed",
  "agents_used": ["review-correctness-defensive", "..."],
  "auto_implemented": [
    { "category": "", "file": "", "description": "", "fix": "" }
  ],
  "for_user_review": [
    { "category": "", "severity": "", "file": "", "lines": "", "description": "", "suggestion": "", "flagged_by": "" }
  ]
}
```

After persisting, direct the user:

> Run `/review-findings` to walk through the remaining findings one-by-one.

## Artifacts

All review artifacts are written to `.claude/artifacts/` with the `standalone_review` prefix (no ticket ID). If the user provides a ticket ID, use that instead.
