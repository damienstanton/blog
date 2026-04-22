---
description: "Master orchestration rule for the harness-kit: when and how to spawn specialized agents, review graph batching, profile-driven configuration."
alwaysApply: true
---

# harness-kit Orchestration

You have access to a network of specialized AI agents defined in `.claude/agents/`. This rule tells you when and how to use them.

## Initialization

Before any implementation work, load a project profile:

```bash
# Load profile
ls .claude/profiles/*.yaml
```

If a profile exists, read it to determine the project's language, toolchain, governance rules, and review graph configuration. All agent spawning decisions flow from the profile.

If no profile exists, infer the project type from the file structure and propose creating one from `.claude/profiles/_template.yaml`.

The `.claude/context/` directory may contain reference material (documentation, code examples, git submodules, or local symlinks) that agents can consult for design decisions. Check it during planning phases.

## Agent Registry

### Testing Agents
| Agent | When to Spawn | Mode |
|-------|--------------|------|
| `test-runner` | After any code change; before review phase | readonly |
| `test-fixer` | After test-runner reports failures AND user confirms | read-write |

### Review Agents (8 lenses)
| Agent | Lens | When to Spawn |
|-------|------|--------------|
| `review-correctness-defensive` | Runtime safety | After tests pass |
| `review-correctness-specification` | Spec adherence | After tests pass |
| `review-quality-structural` | Structural quality | After tests pass |
| `review-quality-evolutionary` | Evolutionary quality | After tests pass |
| `review-docs-consistency` | Documentation | After tests pass |
| `review-error-surface` | Error handling | After tests pass |
| `review-operations-hygiene` | Operations hygiene | After tests pass |
| `review-test-quality` | Test quality | After tests pass |

### Orchestration Agents
| Agent | When to Spawn |
|-------|--------------|
| `planner` | During Planning phase to decompose tickets |
| `implementer` | During Iteration phase to execute plan steps |
| `triager` | During Triage phase to process review findings |

**Parallel dispatch:** When multiple tickets are independent (no shared files, no `related_tickets` edges), the supervisor launches their agents concurrently. See [Ticket Parallelization](#ticket-parallelization) for the full protocol.

### Refactoring Agents
| Agent | Scope | When to Spawn |
|-------|-------|--------------|
| `refactor-small` | Function-level | Via `/refactor` command |
| `refactor-medium` | Module-level | Via `/refactor` command |
| `refactor-large` | Architecture-level | Via `/refactor` command |

### Polyglot Specialist Agents
| Agent | When to Spawn |
|-------|--------------|
| `rust-core` | When implementing Rust core logic in polyglot systems |
| `diplomat-ffi` | When creating or modifying Diplomat FFI bridges |
| `typescript-ui` | When building React/TypeScript frontends |
| `python-agentic` | When building Python data/ML/orchestration layers |
| `c-embedded` | When building C/C++ embedded consumers of FFI |
| `tauri-desktop` | When building Tauri cross-platform desktop apps |
| `tauri-mobile` | When building Tauri mobile apps (iOS, Android, visionOS) |

## Review Graph Batching

When running code review, spawn agents in three batches for efficiency:

**Batch 1 (Correctness — blocking, parallel):**
Launch all at once in a single message:
- `review-correctness-defensive`
- `review-correctness-specification`

**Batch 2 (Quality + Docs — advisory, parallel):**
After Batch 1 completes:
- `review-quality-structural`
- `review-quality-evolutionary`
- `review-docs-consistency`

**Batch 3 (Extended — advisory, parallel):**
After Batch 2 completes:
- `review-error-surface`
- `review-operations-hygiene`
- `review-test-quality`

The profile's `review_graph` section may override this default topology.

## Ticket Parallelization

When `/do-task` has multiple refined tickets, the supervisor builds a dependency graph and dispatches independent tickets to concurrent subagents.

### Dependency Graph Construction

Two tickets are **dependent** if:
- One ticket's `related_tickets` array references the other
- Their affected file sets overlap (both modify the same file)

Two tickets are **independent** if neither condition holds.

### Batch Scheduling

1. Compute dependency edges from `related_tickets` and file-set overlap
2. Topological sort to produce execution batches:
   - **Batch 1:** All graph roots (no unresolved dependencies)
   - **Batch N:** Tickets whose dependencies are all in prior batches
3. Within each batch, all tickets execute in parallel via concurrent subagent calls
4. Between batches, the supervisor verifies results (**local mode:** artifacts exist on disk; **GitHub mode:** parsed subagent responses) and runs cross-cutting validation

### Specialist Agent Selection

Select the best subagent type based on the files each ticket modifies:

| File Pattern | Agent Type | Use When |
|-------------|-----------|----------|
| `*.rs`, `Cargo.toml` | `rust-core` | Rust core logic, algorithms, proptest |
| `#[diplomat::bridge]`, `diplomat.toml` | `diplomat-ffi` | FFI bridge, opaque wrappers, codegen |
| `*.ts`, `*.tsx`, `package.json` | `typescript-ui` | React components, Zustand, typed IPC |
| `*.py`, `pyproject.toml` | `python-agentic` | Data/ML workflows, REDACTED telemetry |
| `*.c`, `*.h`, `CMakeLists.txt` | `c-embedded` | Embedded systems, CMake builds |
| `desktop/src-tauri/`, `tauri.conf.json` (desktop) | `tauri-desktop` | Tauri commands, desktop apps |
| `mobile/src-tauri/`, `tauri.conf.json` (mobile) | `tauri-mobile` | Tauri mobile apps (iOS, Android, visionOS) |
| Mixed, docs, infrastructure | `implementer` | General-purpose changes |

**Selection rules:**
- If ALL modified files match one specialist → use that specialist
- If files span multiple specialists → use `implementer` (general purpose), OR decompose into sub-steps per specialist during planning
- Polyglot tickets (e.g., Rust + TypeScript) follow the build_order from the profile's `extensions.polyglot.build_order` — core first, then FFI, then target layers in parallel

### File-Collision Prevention

When multiple subagents execute in parallel, the supervisor enforces exclusive file ownership:

1. **Exclusive write sets:** Each subagent is assigned the files it may modify. The supervisor constructs these from the ticket's affected files list. No two parallel subagents share a writable file.
2. **Read-only shared access:** All subagents may READ any file. Only WRITES are restricted.
3. **Artifact namespace isolation:** Each ticket writes only to `.claude/artifacts/TASK-NNN_*` files. Ticket ID prefixes guarantee no artifact collisions.
4. **Post-batch verification:** After all subagents in a batch return, the supervisor checks:
   - **Local mode:** Each subagent's output artifacts exist on disk. **GitHub mode:** Each subagent returned structured response text.
   - No files outside the assigned set were modified (compare against pre-batch file state)
   - Cross-cutting tests pass (if applicable)
5. **Deadlock prevention:** The dependency graph is a DAG. If a cycle is detected during construction, the supervisor reports it to the user and requests ticket decomposition.
6. **Conflict recovery:** If a subagent modifies a file outside its exclusive set, the supervisor reverts that change, marks the ticket as blocked, and reports the violation.

## Finding Aggregation

After all review agents return, aggregate findings:

- **High confidence:** Flagged by 2+ agents, OR Critical/High severity from any single agent
- **Medium confidence:** Medium severity from 1 agent only
- **Low confidence:** Low/Info severity from 1 agent only

High-confidence findings are auto-fix candidates. Medium/low go to user review.

## Error Handling

All workflow phases return structured results, never throw exceptions:

```
PhaseResult<T> =
  | {status: "success", value: T, artifacts: [...]}
  | {status: "failure", error: ErrorDetail, partial_artifacts: [...]}
  | {status: "blocked", reason: string, requires_user: true}
```

When blocked, save partial artifacts and report actionable next steps to the user.

## Context Persistence Protocol

Persistent storage is the source of truth for all context. The protocol differs by tracking mode:

**GitHub mode:** The GitHub Issue is the sole source of truth for ticket state. Do NOT write artifact files (plan, manifest, iteration, diff, review, triage, summary) to `.claude/artifacts/`. Use `gh issue comment` for status updates and audit trail. The conversation context carries intermediate state within a session. This eliminates file-write approval prompts and unnecessary disk clutter.

**Local mode:** Ticket files on disk are the source of truth. Manifests and artifacts are written to `.claude/artifacts/` for cross-session context persistence. Every phase emits dual artifacts (JSON + Markdown).

### Before Any Phase

1. **Persist the ticket:**
   - **GitHub mode:** The GitHub Issue is the source of truth. Do NOT write local `.claude/features/todo/TASK-NNN.json` or `.md` files. Do NOT write artifact files. Use `gh issue create` and `gh issue edit` for all ticket operations.
   - **Local mode:** Write the ticket to `.claude/features/todo/` (JSON + MD) at intake; update status to `"refined"` after refinement.
2. **Load the profile** — read the active `.claude/profiles/*.yaml` (skip `_template.yaml`); if none exists, create one from `_template.yaml` before proceeding
3. **Initialize the manifest (local mode only)** — create `.claude/artifacts/TASK-NNN_manifest.json` at the start of implementation (Phase 1 Preflight), not at ticket intake. In GitHub mode, no manifest is written at any point.

### Delegating to a Readonly Agent (planner, test-runner, review-*)

Readonly agents **cannot write files**. The supervisor handles persistence:

1. **Fan-out:** Include context in the `prompt` parameter of the Task tool call. In local mode, write input artifacts to disk and reference their paths. In GitHub mode, include context inline or reference the issue number.
2. **Execute:** Spawn the agent. It returns structured text (JSON code blocks + Markdown).
3. **Fan-in:** Parse the agent's text response. **Local mode:** Write parsed artifacts to `.claude/artifacts/TASK-NNN_<phase>.json` and `.md`. Update the manifest. **GitHub mode:** Use the parsed response directly in conversation context. No disk writes.

### Delegating to a Read-Write Agent (implementer, test-fixer, triager)

1. **Fan-out:** Include context in the `prompt`. In local mode, write input artifacts to disk and specify OUTPUT paths. In GitHub mode, include context inline.
2. **Execute:** Spawn the agent. It modifies code. **Local mode:** Agent also writes artifacts to the OUTPUT paths. **GitHub mode:** Agent modifies code only; no artifact files.
3. **Fan-in:** **Local mode:** Verify output artifacts exist on disk. Update the manifest. **GitHub mode:** Verify code changes via `git diff`.

### After Every Phase

1. **Local mode:** Read the output artifact from disk (input for the next phase). Update the manifest. Update `.claude/features/ticket_tracker.md`.
2. **GitHub mode:** Use conversation context to carry state between phases. No disk writes. Use `gh issue list` to query ticket state.

## Delegation Prompt Template

Every Task tool `prompt` MUST include these context fields so the subagent can locate the ticket and project context. In GitHub mode, subagents resolve `github://issues/<number>` by running `gh issue view <number>`. In local mode, they read the file path directly. Use this template, substituting actual values:

```
TICKET_ID: TASK-NNN
PROFILE: .claude/profiles/<project>.yaml
TICKET: github://issues/<number>   (GitHub mode)
    OR: .claude/features/todo/TASK-NNN.json  (local mode)
```

Then add phase-specific fields:

### Planner (readonly)

```
INPUT: <same as TICKET above — GitHub issue or local file>

Read PROFILE for project structure/toolchain.
Read TICKET for title, description, and acceptance criteria.
Return your plan as:
1. A JSON code block labeled ```json containing the plan.v1 schema
2. A Markdown summary with approach, steps, risks, and effort estimate
```

### Implementer (read-write)

```
INPUT: .claude/artifacts/TASK-NNN_plan.json  (local mode)
    OR: <inline plan from conversation context>  (GitHub mode)

Read PROFILE for toolchain commands (format, lint, test).
Read INPUT for the step list and dependencies.
Implement each step.
Local mode: WRITE results to .claude/artifacts/TASK-NNN_iteration.json and .md
GitHub mode: Report results in conversation; no artifact files.
```

### Test-Runner (readonly)

```
INPUT: .claude/artifacts/TASK-NNN_iteration.json

Read PROFILE for test commands and governance policies.
Run the full test suite.
Return the test report as structured text.
```

### Review Agents (readonly, batched)

```
INPUT_DIFF: <inline diff or path to .claude/artifacts/TASK-NNN_diff.md>
            (GitHub mode: always inline; local mode: may use file path)

Read PROFILE for language and review context.
Review the diff for your assigned lens.
Return findings as a JSON array of finding.v1 objects inside a ```json code block.
```

### Test-Fixer (read-write)

```
INPUT: <test-runner report text or path>

Read PROFILE for toolchain commands.
Fix each failure.
Local mode: WRITE results to .claude/artifacts/TASK-NNN_test_fix.json and .md
GitHub mode: Report results in conversation; no artifact files.
```

### Triager (read-write)

```
INPUT: <review findings — inline or from .claude/artifacts/TASK-NNN_review.json>

Read PROFILE for governance autofix rules.
Read INPUT for review findings.
Apply safe fixes.
Local mode: WRITE results to .claude/artifacts/TASK-NNN_triage.json and .md
GitHub mode: Report results in conversation; no artifact files.
```

### Parallel Ticket Dispatch

When dispatching multiple tickets in parallel, the supervisor includes file-ownership constraints in each subagent's prompt:

```
TICKET_ID: TASK-NNN
PROFILE: .claude/profiles/<project>.yaml
TICKET: github://issues/<number>  (or .claude/features/todo/TASK-NNN.json in local mode)

EXCLUSIVE_FILES: [list of files this subagent may modify]
DO_NOT_MODIFY: [all other files — read-only access only]

You are assigned TASK-NNN. Other tickets are being implemented concurrently by other agents.
Only modify files in EXCLUSIVE_FILES. You may read any file for context.
Local mode: Write artifacts only to .claude/artifacts/TASK-NNN_* (your ticket's namespace).
GitHub mode: No artifact files — report results in your response text.
```

## Context Evolution Manifest (Local Mode Only)

In local mode, the supervisor maintains one manifest per ticket at `.claude/artifacts/TASK-NNN_manifest.json`. This file IS the context evolution graph — it tracks every artifact, what produced it, and the dependency edges.

In GitHub mode, no manifest is written. The GitHub Issue and its comments serve as the audit trail. Conversation context carries intermediate state within a session.

### Schema

```json
{
  "schema_version": "manifest.v1",
  "ticket_id": "TASK-NNN",
  "github_issue": "<number or null>",
  "created": "<ISO 8601>",
  "updated": "<ISO 8601>",
  "nodes": {
    "ticket": {
      "path": "github://issues/<number>",
      "phase": "intake",
      "agent": "supervisor",
      "timestamp": "<ISO 8601>"
    },
    "plan": {
      "path": ".claude/artifacts/TASK-NNN_plan.json",
      "phase": "planning",
      "agent": "planner",
      "timestamp": "<ISO 8601>"
    }
  },
  "edges": [
    {"from": "ticket", "to": "plan"}
  ]
}
```

In local mode, set `"github_issue": null` and use `"path": ".claude/features/todo/TASK-NNN.json"` for the ticket node.

### Node Keys

Use these standard keys for nodes: `ticket`, `plan`, `iteration`, `test_run`, `review`, `triage`, `summary`. For step-level artifacts use `iteration_step_1`, `iteration_step_2`, etc.

### When to Update

- **Intake:** Create manifest with `ticket` node
- **Planning:** Add `plan` node + edge from `ticket`
- **Iteration:** Add `iteration` node + edge from `plan`
- **Testing:** Add `test_run` node + edge from `iteration`
- **Review:** Add `review` node + edges from `iteration` and `test_run`
- **Triage:** Add `triage` node + edge from `review`
- **Closure:** Add `summary` node + edges from all prior nodes, then archive artifacts (see Phase 7 below)

### Phase 7: Closure (supervisor executes directly)

After writing summary and updating the manifest:

```
MKDIR  .claude/artifacts-archive/{TID}/
MOVE   .claude/artifacts/{TID}_* → .claude/artifacts-archive/{TID}/
```

In local mode, update `.claude/features/ticket_tracker.md`. In GitHub mode, skip this step. Completed ticket files stay in `.claude/features/completed/` (in git, local mode only); artifacts and manifest move to the archive (gitignored).

## Reference Specs

For detailed contracts, see the `.claude/specs/` directory:
- `.claude/specs/workflow-contract.md` — CTT-based workflow invariants
- `.claude/specs/phase-orchestrator.md` — Workflow phases
- `.claude/specs/review-rubrics.md` — Review lens definitions
- `.claude/specs/finding-schema.md` — Finding output format
- `.claude/specs/project-profile-schema.md` — Profile configuration
