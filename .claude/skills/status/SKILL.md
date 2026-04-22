<!-- AUTO-GENERATED from .claude/ — do not edit directly. Run: bash .claude/scripts/sync-claude.sh -->
---
name: status
description: Show a dashboard of project state including tickets, artifacts, test health, and next actions.
---
# Project Status

Show a dashboard of the current project state: ticket health, recent artifacts, test status, and suggested next actions.

## When to Use

- Starting a new session (orient yourself)
- After pulling changes or rebasing
- Checking progress across multiple tickets
- Before deciding what to work on next

## Initial Setup

Read the active profile from `.claude/profiles/*.yaml` (skip `_template.yaml`).

If no profile exists:

> No project profile found. Run `/setup-project` to get started.

## Phase 1: Gather State

Collect information from multiple sources. Read all of these:

### 1.1 Tickets

Scan `.claude/features/todo/` for all `.json` files. For each, extract:
- `id`, `title`, `state` (todo / refined / in-progress / blocked)
- Number of acceptance criteria (total and met)

Scan `.claude/features/completed/` for all `.json` files. Count them.

Read `.claude/features/ticket_tracker.md` if it exists.

### 1.2 Artifacts

Scan both `.claude/artifacts/` (active work) and `.claude/artifacts-archive/` (completed tickets) for all files. Group by ticket ID and phase. Identify:
- Which tickets have which phase artifacts
- The most recently modified artifact (indicates last active work)
- Archived artifacts from completed tickets (in `.claude/artifacts-archive/TASK-NNN/`)

### 1.3 Git State

```bash
git status --short
git log --oneline -5
```

Note: uncommitted changes, current branch, recent commits.

### 1.4 Test Health (Quick)

Only if a precheck command is configured and fast (< 10s):

```bash
{{toolchain.precheck_cmd}}
```

Do NOT run the full test suite — that's what `/run-tests-and-fix` is for.

## Phase 2: Present Dashboard

```
## Project Status

**Profile:** .claude/profiles/<name>.yaml
**Language:** <language> | **Branch:** <branch>
**Uncommitted changes:** <yes/no — N files>

### Tickets
| Status | Count | Details |
|--------|-------|---------|
| Todo | N | TASK-003, TASK-005 |
| Refined | N | TASK-001, TASK-002 |
| In Progress | N | TASK-004 (Phase 3: Iteration, step 2/5) |
| Blocked | N | TASK-006 (Phase 4: 2 test failures) |
| Completed | N | Last: TASK-007 (2 hours ago) |

### Recent Activity
| When | What |
|------|------|
| 15 min ago | TASK-004_iteration.json updated |
| 1 hour ago | TASK-007 completed (moved to done) |
| 2 hours ago | TASK-004 started implementation |

### Quick Health
- Precheck: ✅ passed (or ❌ failed — details)
- Uncommitted changes: 3 files modified, 1 untracked

### Suggested Next Actions
1. **Continue TASK-004** — in progress, Phase 3 step 2/5 (`/resume-work`)
2. **Unblock TASK-006** — 2 test failures need attention (`/run-tests-and-fix`)
3. **Start TASK-001** — refined and ready (`/do-task`)
```

## Adapting to Empty Projects

If no tickets, artifacts, or profile exist:

```
## Project Status

This project hasn't been set up for the harness-kit yet.

**Getting started:**
1. `/setup-project` — Create a profile and scaffold directories
2. `/new-task` — Plan your first features
3. `/do-task` — Start building
```

## Adapting to Completed Projects

If all tickets are done and no work is in progress:

```
## Project Status

All N tickets completed. No work in progress.

**What's next?**
- `/new-task` to plan new features
- `/run-tests-and-fix` for a health check
- `/review-code` to review recent changes before release
```
