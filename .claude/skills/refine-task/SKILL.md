<!-- AUTO-GENERATED from .claude/ — do not edit directly. Run: bash .claude/scripts/sync-claude.sh -->
---
name: refine-task
description: List open issues and iteratively refine selected tickets to implementation-ready state.
---
# Refine Tickets

User-facing entry point for iterative ticket refinement. Lists open issues, lets the user select which to refine, and delegates to `/start-ticket-refinement` for each.

## Initial Setup

1. Read the active profile from `.claude/profiles/*.yaml` (skip `_template.yaml`)
2. Detect tracking mode:
   ```bash
   gh auth status 2>/dev/null
   ```

## Step 1: List Open Issues

**GitHub mode:**
```bash
gh issue list --state open --json number,title,labels --limit 100
```

**Local mode:** Scan `.claude/features/todo/` for `.json` files.

## Step 2: Group by Refinement Status

Present issues in two groups:

```
## Not Yet Refined
| # | Title |
|---|-------|
| 42 | TASK: Feature X |
| 43 | TASK: Feature Y |

## Already Refined
| # | Title |
|---|-------|
| 44 | TASK: Feature Z |
```

In GitHub mode, refined status is determined by the `refined` label. In local mode, by `"state": "refined"` in the JSON file.

## Step 3: Select Issues to Refine

```
AskUserQuestion(
  title="Select issues to refine",
  questions=[{
    id: "refine-selection",
    prompt: "Which issues would you like to refine? (Already-refined issues can be re-refined.)",
    options: [
      {id: "unrefined", label: "All unrefined issues"},
      {id: "all", label: "All issues (including already refined)"},
      {id: "select", label: "I'll specify which ones"},
      {id: "cancel", label: "Cancel"}
    ]
  }]
)
```

If "select": ask the user to provide issue numbers.

## Step 4: Refine Each Issue

For each selected issue, invoke `/start-ticket-refinement` with the issue number. Process issues one at a time (refinement is interactive and requires user attention).

After each issue is refined (or the user accepts it), move to the next.

## Step 5: Summary and Transition

When all selected issues have been processed, prompt the user for the next step:

```
AskUserQuestion(
  title="Refinement Complete — Next Step",
  questions=[{
    id: "next-action",
    prompt: "Refined N issues. Ready to start implementation?",
    options: [
      {id: "do-task", label: "Yes — start /do-task"},
      {id: "skip", label: "Not yet — I'll do it manually later"}
    ]
  }]
)
```

If **do-task**: immediately execute the `/do-task` workflow inline.
If **skip**: respond with "N issues refined. Use `/do-task` when you're ready."
