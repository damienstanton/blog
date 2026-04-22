---
description: "Workflow phase reference: Phases 1-7 (preflight through closure). Always in context so agents understand the workflow structure."
alwaysApply: true
---

# Workflow Phases

Every feature implementation follows up to 7 phases. Each phase has a gate — if the gate fails, the workflow blocks and reports to the user.

## Phase 1: Preflight

**Purpose:** Validate environment is ready.

1. Load ticket: `gh issue view <number>` (GitHub mode) or `.claude/features/todo/TASK-NNN.json` (local mode, with `"state": "refined"`)
2. Validate ticket has required fields (title, description, acceptance_criteria)
3. Verify toolchain commands are executable: `{{toolchain.precheck_cmd}}`
4. Check state == "refined" (local) or label == "refined" (GitHub)

**Gate:** If precheck fails → status: "blocked", report to user, EXIT.

## Phase 2: Planning

**Purpose:** Decompose ticket into concrete steps.

1. Read acceptance criteria
2. Identify affected files (semantic search, grep, file tree)
3. Sequence steps with dependencies
4. Estimate scope and risk

**Output (local mode):** `.claude/artifacts/<TICKET>_plan.json` + `.md`
**Output (GitHub mode):** Presented in conversation; no files written.
**Gate:** Plan must cover all acceptance criteria.

## Phase 3: Iteration

**Purpose:** Implement plan with immediate feedback.

For each step:
1. Generate code change
2. Format: `{{toolchain.format_cmd}}`
3. Lint: `{{toolchain.lint_cmd}}`
4. Targeted test: `{{toolchain.test_cmd_targeted}}`
5. If fail → fix (bounded by `{{governance.max_fix_iterations}}`)

**Output (local mode):** `.claude/artifacts/<TICKET>_iteration.json` + `_diff.md`
**Output (GitHub mode):** Code changes only; no artifact files.
**Checklist update (GitHub mode):** After each step, check off the corresponding scope item and any satisfied acceptance criteria in the issue body via `gh issue edit <number> --body-file`. Do not defer updates to the end.
**Gate:** All steps complete or blocked after max retries.

## Phase 4: Testing

**Purpose:** Comprehensive validation.

1. **Focused tests:** `{{toolchain.test_cmd_targeted}}` for affected tests
2. **Full regression:** `{{toolchain.test_cmd_full}}`
3. Apply skip/xfail policies from `{{governance.skip_policy}}`
4. If failures: classify, attempt fix (bounded), re-run

**Output (local mode):** `.claude/artifacts/<TICKET>_test_run.json` + `.md`
**Output (GitHub mode):** Test results reported in conversation.
**Gate:** All tests pass (per policy). Unfixable → blocked.

## Phase 5: Review

**Purpose:** Multi-lens quality assessment.

1. Capture diff: `git diff`
2. **Batch 1 (blocking, parallel):** correctness-defensive + correctness-specification
3. **Batch 2 (advisory, parallel):** quality-structural + quality-evolutionary + docs-consistency
4. **Batch 3 (advisory, parallel):** error-surface + operations-hygiene + test-quality
5. Deduplicate findings across agents
6. Classify by confidence (high/medium/low)

**Output (local mode):** `.claude/artifacts/<TICKET>_review.json` + `.md`
**Output (GitHub mode):** Review findings reported in conversation.
**Gate:** No critical/high findings in blocking batch.

## Phase 6: Triage

**Purpose:** Apply safe auto-fixes.

For each finding:
- confidence >= 0.9 AND risk == "low" → Apply automatically
- confidence >= 0.7 AND risk == "low" → Ask user
- Otherwise → Log as suggestion

After each auto-fix: re-run affected tests. Revert if tests break.

**Output (local mode):** `.claude/artifacts/<TICKET>_triage.json` + `.md`
**Output (GitHub mode):** Triage results reported in conversation.

## Phase 7: Closure

**Purpose:** Finalize and archive.

1. Finalize all checklists in the issue body (scope items, acceptance criteria, definition of done) — all must be `[x]` before posting any completion comment
2. Update ticket: state → "done", acceptance_criteria → met with evidence
   - **GitHub mode:** `gh issue comment <number>` with completion status; issue auto-closes via PR "Closes #N"
   - **Local mode:** Move ticket files from `.claude/features/todo/` → `.claude/features/completed/`
3. **Local mode only:** Generate summary artifact with metrics

**Output (local mode):** `.claude/artifacts/<TICKET>_summary.json` + `.md`
**Output (GitHub mode):** Completion comment posted to issue. No local files.

## Artifact Discipline

**Local mode:** Every phase emits dual artifacts (JSON + Markdown) to `.claude/artifacts/`. All artifacts follow normalization rules (see `artifact-standards.md`).

**GitHub mode:** No artifact files are written to disk. The GitHub Issue and its comments serve as the audit trail. Phase outputs are carried in conversation context. This avoids file-write approval prompts and unnecessary disk I/O.

## Supervisor Disk Operations per Phase (Local Mode)

This section defines the concrete read/write/delegate sequence for **local mode only**. In GitHub mode, replace all WRITE/UPDATE operations on `.claude/artifacts/` with `gh issue comment` or conversation context. See `orchestration.md` for the Delegation Prompt Template and Context Manifest Schema.

Variables used below:
- `TID` = ticket ID (e.g. `TASK-001`)
- `ISSUE_NUM` = GitHub Issue number (e.g. `42`; GitHub mode only)
- `PROF` = active profile path (e.g. `.claude/profiles/my-project.yaml`)

### Phase 1: Preflight (supervisor executes directly)

```
# GitHub mode:
RUN    gh issue view {ISSUE_NUM}                → validate ticket exists & has "refined" label
# Local mode:
READ   .claude/features/todo/{TID}.json         → validate schema & state

READ   {PROF}                                   → extract precheck_cmd
RUN    {{toolchain.precheck_cmd}}
WRITE  .claude/artifacts/{TID}_preflight.json   → result
WRITE  .claude/artifacts/{TID}_preflight.md     → summary
UPDATE .claude/artifacts/{TID}_manifest.json    → add "preflight" node
```

No delegation — the supervisor validates the environment itself.

### Phase 2: Planning (delegate to planner, readonly)

```
# GitHub mode:
RUN    gh issue view {ISSUE_NUM}                → confirm ticket exists
# Local mode:
READ   .claude/features/todo/{TID}.json         → confirm ticket exists on disk

DELEGATE planner (readonly):
  prompt includes: TICKET_ID, PROFILE, TICKET, INPUT
RECEIVE text response from planner
PARSE  JSON code block → .claude/artifacts/{TID}_plan.json
PARSE  Markdown section → .claude/artifacts/{TID}_plan.md
WRITE  .claude/artifacts/{TID}_plan.json        → persist parsed JSON
WRITE  .claude/artifacts/{TID}_plan.md          → persist parsed Markdown
UPDATE .claude/artifacts/{TID}_manifest.json    → add "plan" node, edge ticket→plan
```

### Phase 3: Iteration (delegate to implementer, read-write)

```
READ   .claude/artifacts/{TID}_plan.json       → confirm plan exists on disk
DELEGATE implementer (read-write):
  prompt includes: TICKET_ID, PROFILE, TICKET, INPUT, OUTPUT_JSON, OUTPUT_MD
VERIFY .claude/artifacts/{TID}_iteration.json   → confirm agent wrote output
VERIFY .claude/artifacts/{TID}_iteration.md     → confirm agent wrote summary
UPDATE .claude/artifacts/{TID}_manifest.json    → add "iteration" node, edge plan→iteration
```

### Phase 4: Testing (delegate to test-runner, readonly)

```
READ   .claude/artifacts/{TID}_iteration.json  → confirm iteration complete
DELEGATE test-runner (readonly):
  prompt includes: TICKET_ID, PROFILE, INPUT
RECEIVE text response from test-runner
PARSE  test report text → .claude/artifacts/{TID}_test_run.json
WRITE  .claude/artifacts/{TID}_test_run.json    → persist parsed results
WRITE  .claude/artifacts/{TID}_test_run.md      → persist report text as Markdown
UPDATE .claude/artifacts/{TID}_manifest.json    → add "test_run" node, edge iteration→test_run
```

If failures detected and user confirms fixes:

```
DELEGATE test-fixer (read-write):
  prompt includes: TICKET_ID, PROFILE, INPUT (report), OUTPUT_JSON, OUTPUT_MD
VERIFY .claude/artifacts/{TID}_test_fix.json    → confirm agent wrote output
RE-DELEGATE test-runner                         → verify fixes
```

### Phase 5: Review (delegate to review agents, readonly, batched)

```
RUN    git diff → capture diff text
WRITE  .claude/artifacts/{TID}_diff.md          → persist diff to disk

BATCH 1 (parallel, blocking):
  DELEGATE review-correctness-defensive (readonly):
    prompt includes: TICKET_ID, PROFILE, INPUT_DIFF
  DELEGATE review-correctness-specification (readonly):
    prompt includes: TICKET_ID, PROFILE, INPUT_DIFF, TICKET
  RECEIVE text responses from both agents
  PARSE  JSON arrays from both responses → findings[]

BATCH 2 (parallel, advisory):
  DELEGATE review-quality-structural (readonly)
  DELEGATE review-quality-evolutionary (readonly)
  DELEGATE review-docs-consistency (readonly)
  RECEIVE text responses
  PARSE  JSON arrays → more findings[]

MERGE  all findings → deduplicate by location
WRITE  .claude/artifacts/{TID}_review.json      → merged findings
WRITE  .claude/artifacts/{TID}_review.md        → formatted finding summary
UPDATE .claude/artifacts/{TID}_manifest.json    → add "review" node, edges from iteration + test_run
```

### Phase 6: Triage (delegate to triager, read-write)

```
READ   .claude/artifacts/{TID}_review.json     → confirm review exists on disk
DELEGATE triager (read-write):
  prompt includes: TICKET_ID, PROFILE, INPUT, OUTPUT_JSON, OUTPUT_MD
VERIFY .claude/artifacts/{TID}_triage.json      → confirm agent wrote output
VERIFY .claude/artifacts/{TID}_triage.md        → confirm agent wrote summary
UPDATE .claude/artifacts/{TID}_manifest.json    → add "triage" node, edge review→triage
```

### Phase 7: Closure (supervisor executes directly)

```
# GitHub mode:
RUN    gh issue comment {ISSUE_NUM} --body "..."       → post completion status
       (Issue auto-closes via PR "Closes #N")
       No artifact files written. No manifest update. No archiving.

# Local mode:
READ   .claude/features/todo/{TID}.json                → load ticket
UPDATE ticket: state → "done", acceptance_criteria → met with evidence
WRITE  .claude/features/completed/{TID}.json            → move ticket
WRITE  .claude/features/completed/{TID}.md              → move ticket summary
DELETE .claude/features/todo/{TID}.json                 → remove from todo
DELETE .claude/features/todo/{TID}.md                   → remove from todo
WRITE  .claude/artifacts/{TID}_summary.json     → final summary with metrics
WRITE  .claude/artifacts/{TID}_summary.md       → human-readable summary
UPDATE .claude/artifacts/{TID}_manifest.json    → add "summary" node, edges from all prior nodes
MKDIR  .claude/artifacts-archive/{TID}/         → create archive subdirectory
MOVE   .claude/artifacts/{TID}_* → .claude/artifacts-archive/{TID}/  → archive all artifacts + manifest
UPDATE .claude/features/ticket_tracker.md               → mark ticket as done
```
