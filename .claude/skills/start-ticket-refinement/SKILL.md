<!-- AUTO-GENERATED from .claude/ — do not edit directly. Run: bash .claude/scripts/sync-claude.sh -->
---
name: start-ticket-refinement
description: Iteratively refine a single ticket through feedback, checklist review, and acceptance.
---
# Start Ticket Refinement

Iteratively refine a single ticket until the user accepts it. This is a composable sub-command invoked by `/new-task`, `/refine-task`, and `/do-task`.

The caller provides the issue number (GitHub mode) or ticket ID (local mode).

## Initial Setup

1. Read the active profile from `.claude/profiles/*.yaml` (skip `_template.yaml`)
2. Detect tracking mode (same as `/new-task`):
   ```bash
   gh auth status 2>/dev/null
   ```

## Refinement Loop

### Step 1: Load the Issue

**GitHub mode:**
```bash
gh issue view <number> --json body,title,labels -q '{title: .title, labels: [.labels[].name], body: .body}'
```

**Local mode:** Read `.claude/features/todo/TASK-NNN.json`.

### Step 2: Write Draft File

Write the current body to `.claude/state/issue-<number>-body.md` (GitHub mode) or `.claude/state/TASK-NNN-body.md` (local mode).

### Step 3: Display and Ask

Present the current body in chat, then ask the user how to proceed:

```
AskUserQuestion(
  title="Refine Issue #<N>",
  questions=[{
    id: "refine-action",
    prompt: "Current body for #<N> displayed above. How would you like to proceed?",
    options: [
      {id: "feedback", label: "Provide feedback (I'll type it into chat)"},
      {id: "refine", label: "Run the refinement checklist"},
      {id: "accept", label: "Accept — mark as refined"}
    ]
  }]
)
```

### Step 4: Handle Response

**Path A — Feedback:**
1. Wait for user's free-text feedback in the next chat message
2. Incorporate the feedback into the body
3. Push update directly: `gh issue edit <number> --body "[updated body]"`
4. Loop back to Step 1

**Path B — Refine (Standard Refinement Checklist):**
1. Run all 14 checklist items against the current body
2. Self-answer items resolvable from codebase research (use semantic search, grep, file reads)
3. Queue items needing user input
4. Present a summary: which items pass, which were improved, which need user input
5. If items need user input, ask via **AskUserQuestion**
6. Apply all improvements and push update: `gh issue edit <number> --body "[updated body]"`
7. Loop back to Step 1

**Path C — Accept:**
1. **GitHub mode:** `gh issue edit <number> --add-label "refined"`
2. **Local mode:** Set `"state": "refined"` in the JSON file, update the Markdown status
3. Confirm to user: "Issue #N marked as refined."
4. Return control to the calling command

---

## Standard Refinement Checklist (14 items)

### Completeness
1. Is the Summary clear enough that someone unfamiliar with the codebase could understand what this issue delivers?
2. Are all acceptance criteria specific and testable (no vague language like "works correctly")?
3. Are the scope phases ordered logically for incremental implementation?
4. Are all files to modify/create identified in Related Files?

### Technical Depth
5. Is the technical approach described well enough to start coding without guessing?
6. Are there alternative approaches that should be considered and documented?
7. Are edge cases and error conditions covered?
8. Could this introduce breaking changes to existing functionality?

### Dependencies and Risk
9. Does this depend on other open issues being completed first?
10. Could this conflict with other in-progress work?

### Sizing
11. Is this appropriately sized for a single PR?
12. Can any scope be deferred to a follow-up issue?

### Testing
13. Is the test strategy clear (which tiers: unit, mock, integration)?
14. Are there existing tests that might break?

### How to Apply the Checklist

For each item, the agent evaluates the current issue body and categorizes the result:

| Result | Meaning |
|--------|---------|
| Pass | Item is already addressed in the body |
| Auto-improved | Agent resolved the item from codebase research and updated the body |
| Needs user input | Agent cannot resolve without user decision — queued for AskUserQuestion |
| N/A | Item does not apply to this type of ticket |

Present the results as a table, then ask the queued questions.

---

## Local Mode Adaptations

In local mode, replace all `gh` commands with direct file reads/writes:
- Load ticket: read `.claude/features/todo/TASK-NNN.json`
- Update ticket: write both `.claude/features/todo/TASK-NNN.json` and `.md`
- Mark refined: set `"state": "refined"` in JSON, update Markdown status

**For local mode only:** The Review Before Push pattern applies. Write a draft file at `.claude/state/TASK-NNN-body.md`, let the user review, then update the ticket files. This is kept for local mode because local ticket files are harder to inspect and undo than GitHub Issues.
