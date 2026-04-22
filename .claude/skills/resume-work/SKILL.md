<!-- AUTO-GENERATED from .claude/ — do not edit directly. Run: bash .claude/scripts/sync-claude.sh -->
---
name: resume-work
description: Find in-progress, blocked, or ready-to-start tickets and continue the most relevant one.
---
# Resume Work

Pick up where you left off. Finds in-progress, blocked, or ready-to-start tickets and offers to continue the most relevant one.

## When to Use

- Starting a new chat session after the previous one ended mid-ticket
- Coming back to a project after a break
- After a crash, timeout, or interrupted workflow
- When you know there's unfinished work but don't remember the details

## Initial Setup

Read the active profile from `.claude/profiles/*.yaml` (skip `_template.yaml`).

## Phase 1: Find Resumable Work

Read ALL `.json` files from `.claude/features/todo/` and `.claude/features/completed/`. Build a priority-ordered list:

### Priority 1: In-Progress Tickets

Tickets with `"state": "in-progress"` or that have iteration artifacts but no summary artifact.

For each, determine the **last completed phase** by checking which artifacts exist:
- `_preflight.json` → stopped after preflight
- `_plan.json` → stopped after planning
- `_iteration.json` → stopped after iteration
- `_test_run.json` → stopped after testing
- `_review.json` → stopped after review
- `_triage.json` → stopped after triage
- No `_summary.json` → not yet closed

Also check the manifest at `.claude/artifacts/TASK-NNN_manifest.json` for the full artifact graph.

For completed tickets, artifacts and manifests are in `.claude/artifacts-archive/TASK-NNN/` instead of `.claude/artifacts/`.

### Priority 2: Blocked Tickets

Tickets with `"state": "blocked"` or artifacts containing `"status": "blocked"`.

Read the most recent artifact to understand why it's blocked.

### Priority 3: Refined Tickets (Ready to Implement)

Tickets with `"state": "refined"` — planned and approved but not started.

### Priority 4: Todo Tickets (Need Refinement)

Tickets with `"state": "todo"` — drafted but not yet refined.

## Phase 2: Present Options

```
## Resumable Work

### In Progress (pick up where you left off)
1. **TASK-004: Add retry logic to HTTP client**
   Last phase: Iteration (step 2/5 complete)
   Artifacts: plan ✅, iteration (partial) ✅
   → Resume at: Iteration step 3

2. **TASK-008: Refactor error handling**
   Last phase: Testing (2 failures detected)
   Artifacts: plan ✅, iteration ✅, test_run ✅ (failures)
   → Resume at: Fix test failures

### Blocked (needs your input)
3. **TASK-006: Add rate limiting**
   Blocked reason: 2 test failures after max fix iterations
   → Options: review failures, adjust policy, or mark xfail

### Ready to Start
4. **TASK-001: Implement user authentication** (refined)
5. **TASK-002: Add logging middleware** (refined)

Which one? (number, or "1" to continue the most recent)
```

## Phase 3: Resume Selected Ticket

**Note:** Active ticket artifacts are in `.claude/artifacts/`. Completed ticket artifacts are archived to `.claude/artifacts-archive/TASK-NNN/`. Only active tickets can be resumed.

Based on the user's choice and the last completed phase:

### Resuming Iteration
1. Read `.claude/artifacts/TASK-NNN_plan.json` for the full step list
2. Read `.claude/artifacts/TASK-NNN_iteration.json` for completed steps
3. Identify the next incomplete step
4. Continue the implementation loop from `/do-task` (format, lint, test after each change)

### Resuming After Test Failures
1. Read `.claude/artifacts/TASK-NNN_test_run.json` for failure details
2. Present failures to user
3. Offer: auto-fix (launch `test-fixer`), manual guidance, or adjust policy

### Resuming After Review
1. Read `.claude/artifacts/TASK-NNN_review.json` for findings
2. Present unresolved findings
3. Continue with triage phase from `/do-task`

### Resuming a Blocked Ticket
1. Read the blocking artifact to understand the issue
2. Present the block reason and options
3. Wait for user guidance before proceeding

### Starting a Refined Ticket
1. Transition to the implementation workflow
2. Follow `/do-task` from the beginning (preflight, plan, iterate)

## Phase 4: Handoff to Implementation

Once the user selects a ticket and the resume point is clear, continue execution following the same protocol as `/do-task`:

- Format/lint/test after every change
- 8-agent review after tests pass
- Iteration report after each turn
- User gates commits

The key difference from `/do-task` is that this command **skips already-completed phases** by reading existing artifacts instead of re-generating them.
