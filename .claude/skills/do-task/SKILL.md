<!-- AUTO-GENERATED from .claude/ — do not edit directly. Run: bash .claude/scripts/sync-claude.sh -->
---
name: do-task
description: Implement a refined ticket with TDD, 8-agent code review, and automated testing.
---
# Feature Implementation (GitHub Issues)

## Role

You are an expert software engineer specializing in incremental, test-driven development. Focus on maintainability, correctness, and type-driven design.

**Success Criteria:**
- Tests written before implementation (TDD — see Section 5)
- All tests pass; 0 failed, 0 skipped
- Code passes linting and formatting checks
- Changes are minimal and focused on requirements

**Mandatory Checkpoints:**
- Before starting: Run preflight checks to verify environment
- Before implementing: Write failing test(s) defining success criteria
- After each code change: Run tests immediately
- After tests pass: Run code review
- Before completion: Format code and verify all tests pass

---

## Initial Setup

1. Read the active profile from `.claude/profiles/*.yaml` (skip `_template.yaml`) for toolchain, governance, and review configuration
2. Read [AGENTS.md] for repo structure and coding standards
3. **Detect tracking mode** — same detection as `/new-task`:

```bash
gh auth status 2>/dev/null
```

| Condition | Mode | Ticket source |
|-----------|------|---------------|
| `gh auth status` succeeds | **GitHub mode** | GitHub Issues via `gh` CLI |
| `gh` not installed, not authenticated, or user requests local | **Local mode** | `.claude/features/todo/TASK-NNN.json` files |

If the profile specifies `extensions.tracking.mode`, use that.

---

## Before Starting

### 0. Pre-Flight Checks (MANDATORY)

```bash
{{toolchain.precheck_cmd}}
```

If pre-flight fails, resolve before proceeding.

### 1. Load Ticket (MANDATORY)

The user may invoke this command with an optional issue number: `/do-task` or `/do-task 42`.

#### Path A: Issue Number Provided

When the user specifies a number (e.g., `/do-task 42`):

**GitHub mode:**
```bash
gh issue view <number> --json number,title,labels,state
```

1. **Validate** the issue exists. If not found, report the error and fall through to Path B
2. **Check state:** if the issue is closed, report and fall through to Path B
3. **Check labels:** if `in-progress` label is present, warn the user ("Issue #N is already in-progress — continue anyway?") via `AskUserQuestion`
4. **Check refinement:** if the `refined` label is missing, delegate to `/start-ticket-refinement` (see "Handle Unrefined Tickets" below) before proceeding
5. **Proceed** to implementation with the validated issue

**Local mode:** Read `.claude/features/todo/TASK-NNN.json` directly. Validate it exists and check `"state"`.

#### Path B: No Issue Number (Interactive Selection)

**GitHub mode:**

```bash
gh issue list --state open --json number,title,labels,state --limit 100
```

1. **Fetch issues** from GitHub
2. **Partition** into two groups:
   - **Ready** — issues with the `refined` label and without `in-progress`
   - **Other open** — all remaining open issues (unrefined, in-progress, etc.)
3. **Check for sub-issues** only after the user selects an issue (not for every issue in the list — avoid N+1 API calls):
   ```bash
   gh api /repos/{owner}/{repo}/issues/<selected-number>/sub_issues --jq '.[] | {number, title, state}'
   ```
   If the selected issue has sub-issues, display the hierarchy and let the user pick a sub-task or the parent.
4. **Handle edge cases:**
   - No open issues at all → "No open issues found. Use `/new-task` to create one."
   - No ready issues (all in-progress or unrefined) → show the Other group and explain why each isn't ready. Offer to refine an unrefined issue or continue an in-progress one.
5. **Present** using `AskUserQuestion`:

```
AskUserQuestion(
  title="Select a task",
  questions=[{
    id: "task-select",
    prompt: "<table of Ready issues, with sub-issue hierarchy if applicable>\n\n<table of Other issues, if any, with status notes>",
    options: [
      {id: "issue-42", label: "#42 — Title of issue"},
      {id: "issue-43", label: "#43 — Title of issue"},
      ...
    ]
  }]
)
```

6. **Proceed** with the selected issue

**When to read an issue in full:** Only when the user selects it (or provides it directly via Path A).

#### Local Mode (Path B)

Read all `.json` files in `.claude/features/todo/`:

1. **Scan** `.claude/features/todo/` for ticket files
2. **Partition** into Ready (`"state": "refined"`) and Other groups
3. **Present** all tickets with state info and ask which to work on via `AskUserQuestion`

### 2. Handle Unrefined Tickets

If the user selects a ticket that is not yet refined, delegate to `/start-ticket-refinement`:

1. Invoke `/start-ticket-refinement` with the issue number (GitHub mode) or ticket ID (local mode)
2. The refinement loop handles the iterative cycle (Feedback / Refine / Accept) and the 14-item Standard Refinement Checklist
3. Once the user accepts the issue, `/start-ticket-refinement` marks it as refined and returns control here
4. Proceed to implementation

### 3. Analyze Ticket (Multi-Ticket Mode)

When implementing multiple refined tickets in a session:

1. **Build dependency graph:**
   - Parse `related_tickets` or issue cross-references
   - Identify affected files per ticket (from acceptance criteria, technical details, or semantic search)
   - Two tickets are **dependent** if: one references the other, OR their affected file sets overlap
   - Two tickets are **independent** if: no dependency relationship and disjoint file sets
2. **Compute execution batches:**
   - **Batch 1:** All tickets with no unresolved dependencies (graph roots)
   - **Batch 2:** Tickets whose dependencies are all in Batch 1
   - Continue until all tickets are scheduled
   - Independent tickets within the same batch execute in parallel
3. **Select specialist agents** for each ticket based on affected files (see Specialist Agent Selection below)
4. **Assign exclusive file sets** to prevent collisions: each parallel subagent is told which files it owns and must not modify files outside its set
5. Present the execution plan to user

---

## Implementation Workflow

### 1. Update Ticket Status

When starting implementation of a selected ticket:

**GitHub mode:**
```bash
gh issue edit <number> --add-label "in-progress"
gh issue comment <number> --body "Started implementation"
```

**Local mode:** Update the JSON ticket file to reflect in-progress state, update the Markdown status, and update `.claude/features/ticket_tracker.md` to reflect the active ticket.

### 2. Pre-Implementation Briefing (MANDATORY Before Coding)

Before creating a branch or writing code, present a structured briefing:

1. **Overview paragraph** — What, why, and how it fits into the system
2. **Plan of changes** — Numbered list of files to modify/create, what each change does, implementation order
3. **Outstanding questions** — Use `AskUserQuestion` for design decisions, ambiguities, or scope decisions. If none: state "No outstanding questions" and confirm readiness to proceed.

**Do NOT proceed until the user has reviewed the briefing and answered all questions.**

**Local mode only:** Write the plan to `.claude/artifacts/TASK-NNN_plan.json` + `.md` and update `.claude/artifacts/TASK-NNN_manifest.json`.
**GitHub mode:** Do NOT write plan or manifest files. The briefing presented in conversation is the plan.

### 3. Branch Creation

**GitHub mode** — check for an existing branch before creating one. `gh issue develop` appends `-1`, `-2`, etc. when a branch already exists, producing duplicates.

```bash
# 1. Fetch latest remote refs so remote-only branches are visible.
git fetch origin

# 2. Look for an existing branch for this issue (local or remote).
#    Anchor the pattern so issue 42 doesn't match branch 142-*.
LOCAL=$(git branch --list "<number>-*" | head -1 | xargs)
REMOTE=$(git branch -r --list "origin/<number>-*" | head -1 | sed 's|origin/||' | xargs)
EXISTING="${LOCAL:-$REMOTE}"

if [ -n "$EXISTING" ]; then
    # 3a. Branch exists — check it out (create local tracking branch if remote-only).
    git checkout "$EXISTING" 2>/dev/null || git checkout --track "origin/$EXISTING"
else
    # 3b. No branch yet — create one linked to the issue.
    gh issue develop <number> --checkout
fi
```

If you need to specify a base branch when creating:
```bash
gh issue develop <number> --base integration/v1.4 --checkout
```

Do NOT call `gh issue develop` if a branch already exists — it will create a duplicate with a numeric suffix. Do NOT fall back to `git checkout -b` — it creates an unlinked branch with a different name. If `gh issue develop` fails and no existing branch is found, diagnose the error before retrying.

**Local mode** — create a branch manually using the project's branch naming convention:

```bash
git checkout -b feat/short-description
```

Use the branch prefix that matches the ticket label (`feat/`, `fix/`, `task/`, `docs/`, `test/`).

### 4. Implementation

For each step identified in the briefing:
1. **Write a failing test** that captures the desired behavior
2. **Implement the minimal code** to make the test pass
3. **Run tests** — confirm nothing regressed
4. **Format:** `{{toolchain.format_cmd}}`
5. **Lint:** `{{toolchain.lint_cmd}}`
6. If any fail, fix and retry (bounded by `{{governance.max_fix_iterations}}`)

**Rules:**
1. Follow coding standards from AGENTS.md and the project profile
2. Make small, testable changes
3. Document as you go — docstrings explain "why", not "what"
4. Know when to revert — use git to undo problematic changes quickly
5. Update related documentation (README, specs, etc.)

### 4b. Update Issue Checklists (MANDATORY After Each Step)

After completing each implementation step, check off the corresponding items in the issue body immediately. This covers **both** scope checklist items (the per-phase task checkboxes) **and** acceptance criteria:

**GitHub mode:**
1. Fetch the current issue body: `gh issue view <number> --json body -q .body`
2. Check off completed scope items: change `- [ ]` to `- [x]` for each scope task completed by this step
3. Check off satisfied acceptance criteria: change `- [ ]` to `- [x]` for each criterion met by this step
4. Write updated body to `.claude/state/issue-<number>-body.md`
5. Push the update (no AskUserQuestion gate — checkoffs are mechanical):
   ```bash
   gh issue edit <number> --body-file .claude/state/issue-<number>-body.md
   ```

**Local mode:** Update both `.claude/features/todo/TASK-NNN.json` (set `"met": true` with `"evidence"`) and the Markdown file directly.

Do NOT defer checklist updates to the end of implementation. Each scope item and acceptance criterion should be checked off as soon as the code satisfying it is written and verified.

### 5. Testing (MANDATORY After Every Code Change)

#### 5a. TDD Workflow: Tests Come First

For every change, follow this order:

1. **Write a failing test** that captures the desired behavior (or reproduces the bug)
2. **Run the test** — confirm it fails for the right reason
3. **Implement the minimal code** to make the test pass
4. **Run all tests** — confirm nothing regressed
5. **Refactor** if needed, re-running tests after each change

#### 5b. Running Tests

Delegate to `test-runner` (readonly) or run directly:

```bash
{{toolchain.test_cmd_full}}
```

**Requirements:** All tests must pass (0 failed, 0 skipped per governance policy) before moving forward.

If failures and user confirms fixes: delegate to `test-fixer` (read-write) with the failure report. **Local mode:** Verify output artifacts exist on disk. **GitHub mode:** Use parsed response from subagent. Re-run tests to verify.

#### 5c. Test Failure Decision Tree

```
Test Failed?
  +-> Existed BEFORE this session?
  |     +-> YES -> Analyze root cause deeply
  |     |         +-> My change is correct? -> Summarize and ask user about test
  |     |         +-> My change is wrong? -> Revert my change
  |     +-> NO -> Created this session -> Fix it (my responsibility)
  +-> Document: what failed, why, root cause, proposed fix or revert
```

### 6. Code Review (After Tests Pass)

Capture the diff with `git diff`.

**Local mode only:** Write the diff to `.claude/artifacts/TASK-NNN_diff.md`.
**GitHub mode:** Pass the diff inline to review agents. Do NOT write diff or review artifact files.

Run review in three batches:

**Batch 1 (Correctness — blocking, parallel):**
Launch `review-correctness-defensive` and `review-correctness-specification` with the diff. Parse JSON findings from their responses.

**Batch 2 (Quality + Docs — advisory, parallel):**
Launch `review-quality-structural`, `review-quality-evolutionary`, and `review-docs-consistency`. Parse JSON findings.

**Batch 3 (Extended — advisory, parallel):**
Launch `review-error-surface`, `review-operations-hygiene`, and `review-test-quality`. Parse JSON findings.

Merge all findings, deduplicate by location.
**Local mode only:** Write merged findings to `.claude/artifacts/TASK-NNN_review.json` + `.md`.
**GitHub mode:** Present findings in the iteration report. No artifact files.

Aggregate findings by confidence:
- **High:** 2+ agents, or Critical/High from any agent — Auto-fix candidate
- **Medium/Low:** Include in report for user review

**Persist for walkthrough:** Write findings to `.claude/state/review-findings.json` with auto-implemented and for-user-review lists separated. Direct the user: "Run `/review-findings` to walk through the remaining findings one-by-one."

### 7. Formatting (MANDATORY Before Completion)

```bash
{{toolchain.format_cmd}}
{{toolchain.lint_cmd}}
```

---

## Parallel Dispatch (Multi-Ticket Mode)

When implementing multiple tickets in a single session, use subagent dispatch:

For each batch (in dependency order):

1. **Fan out:** Launch one subagent per ticket in the batch, concurrently. Use the Task tool to spawn multiple subagents in a single message. Each subagent receives:
   - The ticket (TICKET_ID, acceptance criteria, description)
   - The profile (toolchain commands, governance rules)
   - Its exclusive file set (files it may modify — no other subagent touches these)
   - The specialist agent type (selected in Analyze step)

2. **Subagent executes the per-ticket workflow** (each subagent independently):
   - Plan: analyze acceptance criteria, identify steps
   - Implement: make changes to its exclusive file set only
   - Validate: format, lint, targeted tests (if applicable)
   - **Local mode:** Write iteration artifacts to `.claude/artifacts/TASK-NNN_*`
   - **GitHub mode:** Report results in response text; no artifact files

3. **Supervisor verifies** after all subagents in the batch return:
   - **Local mode:** Read each subagent's artifacts from disk
   - **GitHub mode:** Parse each subagent's response text
   - Verify no file-set violations (no subagent touched another's files)
   - Run any cross-cutting validation (e.g., full test suite if code changed)
   - If any subagent blocked, handle before proceeding to next batch

4. **Next batch:** Only proceed when all tickets in the current batch are verified

---

## Specialist Agent Selection

When dispatching to subagents, select the best agent for the ticket's domain:

| Affected Files | Agent | Capabilities |
|---------------|-------|-------------|
| `.rs`, `Cargo.toml` | `rust-core` | Provably correct algorithms, builder patterns, proptest |
| `#[diplomat::bridge]`, `diplomat.toml` | `diplomat-ffi` | Safe FFI bridge, opaque wrappers, typed errors |
| `.ts`, `.tsx`, `package.json` | `typescript-ui` | React components, Zustand stores, typed IPC |
| `.py`, `pyproject.toml` | `python-agentic` | Data analysis, ML workflows, REDACTED observability |
| `.c`, `.h`, `CMakeLists.txt` | `c-embedded` | Embedded systems, CMake, platform-specific libs |
| `src-tauri/`, `tauri.conf.json` | `tauri-desktop` | Tauri commands, desktop apps, event streaming |
| Mixed/docs/infrastructure | `implementer` | General-purpose implementation |

**Fallback:** If no specialist matches, use `implementer`.

**Polyglot tickets:** If a ticket spans multiple languages (e.g., Rust core + TypeScript UI), it should be decomposed into layer-specific sub-steps during planning, with each step delegated to the appropriate specialist. The supervisor coordinates the sequence.

---

## Collision Prevention

When multiple subagents execute in parallel, file ownership prevents conflicts:

1. **Exclusive file sets:** Each subagent is assigned files it may modify. No two parallel subagents share a file.
2. **Artifact namespace isolation (local mode):** Each ticket writes only to `.claude/artifacts/TASK-NNN_*` — ticket IDs prevent namespace collisions. In GitHub mode, no artifact files are written.
3. **Read-only shared access:** All subagents may READ any file in the repo. Only WRITES are restricted to the exclusive set.
4. **Conflict detection:** After a batch completes, the supervisor runs `git diff` to verify no unexpected file modifications occurred outside assigned sets.
5. **Deadlock prevention:** Dependencies are resolved before dispatch. If a circular dependency is detected during graph construction, report it to the user and request decomposition.

---

## Iteration Report (MANDATORY After Every Turn)

Output this report after **every turn that makes changes** — initial implementation, revision rounds, test fixes, lint fixes. The report reflects the **current cumulative state**, not just the delta.

### Batch Report (when parallel execution used)

```markdown
## Batch N Complete

| Ticket | Agent | Status | Duration |
|--------|-------|--------|----------|
| TASK-003 | implementer | done | 12s |
| TASK-005 | implementer | done | 8s |

**File collision check:** No violations
**Cross-cutting tests:** Passed (or N/A for docs-only)

Proceeding to Batch N+1...
```

### Task Report: Issue #[number]

#### Summary
[What was implemented and WHY the approach works.
On revision rounds, note what changed since the last iteration.]

#### What Was Implemented
[Numbered list of each feature/change with a brief description of what it does and why]

#### Files Changed
| File | Change |
|------|--------|
| `path/file.py` | Added X function for Y reason |
| `path/test.py` | Added N tests covering Z scenarios |

#### Test Results
- Tests: X passed, 0 failed, 0 skipped
- Lint: All checks passed
- Warning: [Any warnings, known flaky tests, or notes]

#### Code Review Findings
**Review agents:** 5 (Correctness x2, Quality x2, Docs)

##### Auto-Implemented (High Confidence)
| # | Category | File | Fix Applied |
|---|----------|------|-------------|

##### For User Review (Medium/Low)
| # | Category | Severity | File | Suggestion |
|---|----------|----------|------|------------|

#### Scope Items (verified against issue body)
- [x] Phase 1 item — Done (issue body updated)
- [ ] Phase 2 item — Not yet started

#### Acceptance Criteria (verified against issue body)
- [x] Criterion 1 - Done (issue body updated)
- [ ] Criterion 2 - Not done (explain why)

Before presenting these sections, fetch the current issue body (`gh issue view <number>`) and cross-reference: every item shown as `[x]` here MUST also be `[x]` in the issue body. If any are out of sync, update the issue body first, then present the report.

#### Outstanding Questions
[Numbered list of open questions. If none: "None — implementation is straightforward."]

#### Recommendations
[Numbered list of follow-up improvements discovered during implementation.]

#### Suggested Commit Message

Use the prefix matching the branch type:

| Branch Prefix | Commit/PR Prefix |
|---------------|------------------|
| `feat/`       | `feat:`          |
| `bug/`        | `fix:`           |
| `fix/`        | `fix:`           |
| `docs/`       | `docs:`          |
| `test/`       | `test:`          |
| `hotfix/`     | `fix:`           |
| `task/`       | `task:`          |

For branches created via `gh issue develop` (e.g. `42-description`), infer the prefix from the linked issue's labels: `feature` -> `feat:`, `bug` -> `fix:`, `task` -> `task:`.

```
<prefix>(scope): [primary change] with [key supporting details]

- [Bullet for each major change]

Closes #[issue-number]
```

#### Next Steps
1. Review changes with `git status` and `git diff`
2. Review the commit the agent made
3. When ready, the agent will prompt to start `/open-pr` automatically

---

## Task Completion

1. **Finalize all checklists (MANDATORY — before posting any completion comment):**

   Verify every scope item, acceptance criterion, and definition-of-done item is checked off in the issue body:

   **GitHub mode:**
   1. Fetch the issue body: `gh issue view <number> --json body -q .body`
   2. Check every `- [ ]` scope item — if completed, change to `- [x]`
   3. Check every `- [ ]` acceptance criterion — if satisfied, change to `- [x]`
   4. Check every `- [ ]` definition-of-done item — if met (except "PR created"), change to `- [x]`
   5. If any updates are needed, write to `.claude/state/issue-<number>-body.md` and push:
      ```bash
      gh issue edit <number> --body-file .claude/state/issue-<number>-body.md
      ```
   6. If any criteria remain unchecked, explain why in the status comment

   **Local mode:** Update ticket JSON: set `"met": true` and `"evidence"` for each satisfied criterion.

2. **Post status update (only after step 1 is complete):**

   **GitHub mode:**
   ```bash
   gh issue comment <number> --body "Implementation complete. Awaiting PR and review."
   ```

   **Local mode:** Update ticket JSON: set `"state": "done"`. Move both files from `.claude/features/todo/` to `.claude/features/completed/`.

3. **Update artifacts (local mode only):**
   - Write summary: `.claude/artifacts/TASK-NNN_summary.json` + `.claude/artifacts/TASK-NNN_summary.md`
   - Update manifest: add `summary` node with edges from all prior nodes
   - Archive artifacts: move `.claude/artifacts/TASK-NNN_*` to `.claude/artifacts-archive/TASK-NNN/`
   - Update `.claude/features/ticket_tracker.md`

   **GitHub mode:** Skip all artifact writes. The issue comment and PR serve as the audit trail.

4. **Prompt next step:**

   The agent commits the implementation to the feature branch. Then prompt the user for the next action:

   ```
   AskUserQuestion(
     title="Implementation Complete — Next Step",
     questions=[{
       id: "next-action",
       prompt: "Issue #N implemented and committed. Ready to open a PR?",
       options: [
         {id: "open-pr", label: "Yes — start /open-pr"},
         {id: "skip", label: "Not yet — I'll do it manually later"}
       ]
     }]
   )
   ```

   If **open-pr**: immediately execute the `/open-pr` workflow inline (no need for the user to type the command).
   If **skip**: respond with "Issue #N implemented. Use `/open-pr` when you're ready."

---

## Error Handling & Recovery

Errors are information. Analyze systematically, document reasoning, propose recovery paths.

### Test Failures

1. **Classify:** Pre-existing test or created this session?
2. **Analyze:** What failed, why, after which change, root cause
3. **Decide:**
   - Pre-existing test broke -> summarize analysis, ask user whether to fix implementation or update test
   - New test broke -> fix it (your responsibility)
   - Uncertain -> propose options with confidence levels and risk assessment
4. **If a fix causes more failures:** Revert and try a different approach

### Revert Required

When a change causes problems beyond what you can fix:
1. Explain what went wrong and why reverting is best
2. List files to revert with `git checkout HEAD -- path/file.py`
3. Propose an alternative approach

### Implementation Blocked

When blocked, describe the blocker and present options: workaround, alternative approach, or skip to another task.

---

## Documentation Standards

Every change should include:
1. **Docstrings** — Explain type-level invariants and intent, not mechanics
2. **Inline comments** — Explain "why", not "what"
3. **Type annotations** — All public functions fully annotated
4. **No task numbers in user-facing docs** — Use descriptive language in README/SDK docstrings/public API docs. Task numbers are allowed in internal code comments, test docstrings, ticket files, and commit messages.

---

## Start

The user may provide an issue number after the command: `/do-task` or `/do-task 42`.

Respond with:
1. **Detect tracking mode** (check `gh auth status`)
2. **Check for issue number argument:**
   - If provided (e.g., `/do-task 42`): validate the issue via Path A, then start implementation
   - If not provided: continue to step 3
3. **Load tickets via Path B (interactive selection):**
   - GitHub mode: fetch open issues, partition by readiness, display sub-issue hierarchies, prompt via `AskUserQuestion`
   - Local mode: scan `.claude/features/todo/`, partition by state, prompt via `AskUserQuestion`
4. **Local mode only:** Update `.claude/features/ticket_tracker.md` with current state
5. Start implementation on the selected issue
