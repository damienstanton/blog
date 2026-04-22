<!-- AUTO-GENERATED from .claude/ — do not edit directly. Run: bash .claude/scripts/sync-claude.sh -->
---
name: review-findings
description: Walk through code review findings one-by-one with fix, defer, or skip options.
---
# Review Findings Walkthrough

Walk through code review findings one-by-one, presenting structured options (fix / defer / skip) for each. This command is invoked after `/review-code`, `/run-tests-and-fix`, or `/do-task` has persisted findings.

## Initial Setup

1. Read the active profile from `.claude/profiles/*.yaml` (skip `_template.yaml`) for toolchain commands
2. Detect tracking mode:
   ```bash
   gh auth status 2>/dev/null
   ```

## Step 1: Load Findings

Check in order:

1. **Session context** — if a review just ran in this conversation, use those findings directly
2. **Persisted file** — read `.claude/state/review-findings.json`
3. **Neither available** — tell the user: "No review findings found. Run `/review-code` first."

### Findings File Format

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

## Step 2: Present Overview

Show a summary of what's been done and what's left:

```
## Review Findings Overview

**Auto-implemented** (already fixed during review):
| # | Category | File | Fix Applied |
|---|----------|------|-------------|

**For your review** (N findings):
| # | Category | Severity | File | Lines | Description |
|---|----------|----------|------|-------|-------------|
```

If `for_user_review` is empty, report "All findings were auto-implemented. No user review needed." and skip to Step 4.

## Step 3: Per-Finding Walkthrough

For each finding in `for_user_review`:

### 3a. Present the Finding

1. Describe the issue: what the reviewer flagged and why it matters
2. Show the current code by reading the referenced file and lines
3. Show the reviewer's suggestion

### 3b. Ask for Disposition

```
AskUserQuestion(
  title="Review Finding [N] of [total]",
  questions=[{
    id: "finding-<N>",
    prompt: "**[Category] — [Severity]**\nFile: <path>:<lines>\n\n<description>\n\n<reviewer recommendation>",
    options: [
      {id: "fix1", label: "Fix now: <primary approach>"},
      {id: "defer", label: "Defer — create follow-up ticket"},
      {id: "skip", label: "Skip (low risk / disagree)"}
    ]
  }]
)
```

Add a second "fix" option when there's a meaningfully different alternative approach. Omit it when there's only one obvious fix.

### 3c. Act on Choice

**Fix now:**
1. Implement the fix
2. Run targeted tests: `{{toolchain.test_cmd_targeted}}`
3. If tests pass, record as "Fixed" and continue
4. If tests fail, revert the fix and record as "Fix attempted — reverted, tests failed"

**Defer:**
1. **GitHub mode:** Create a follow-up issue:
   ```bash
   gh issue create --title "task: Fix [category] in [file]" --body "..." --label "task"
   ```
2. **Local mode:** Create a local ticket in `.claude/features/todo/`
3. Record as "Deferred" with the issue/ticket reference

**Skip:**
1. Record as "Skipped" with the user's implicit rationale (low risk or disagreement)
2. Continue to next finding

## Step 4: Disposition Summary

### Counts Table

```
| Disposition | Count |
|-------------|-------|
| Fixed       | N     |
| Deferred    | N     |
| Skipped     | N     |
| **Total**   | **N** |
```

### Detail Table

```
| # | Category | Severity | File | Description | Disposition | Notes |
|---|----------|----------|------|-------------|-------------|-------|
```

## Step 5: Final Checks

1. Re-run full test suite: `{{toolchain.test_cmd_full}}`
2. Run formatting: `{{toolchain.format_cmd}}`
3. Run linting: `{{toolchain.lint_cmd}}`
4. Report results

## Step 6: Cleanup

Delete `.claude/state/review-findings.json` to prevent stale findings in future sessions.
