# Phase Orchestrator: Generic Implementation Workflow

This specification defines the **universal phase primitives** for orchestrating implementation workflows across any language/project $L$. It abstracts the process from [/do-task](../commands/do-task.md) into reusable, composable building blocks.

---

## I. Overview

The orchestrator manages the **end-to-end implementation flow**:
0. **Bootstrap**: Discover and instantiate project templates *(conditional)*
1. **Preflight**: Validate environment and inputs
2. **Planning**: Decompose ticket into actionable steps
3. **Iteration**: Small change → immediate validation loop
4. **Testing**: Focused → broad regression testing
5. **Review**: Multi-lens quality assessment
6. **Triage**: Consolidate findings and apply fixes
7. **Closure**: Finalize artifacts and update ticket

All phases are parameterized by [project profile](./project-profile-schema.md) and follow [workflow contract](./workflow-contract.md) invariants. The orchestrator implements the CTT dynamics ([basis.md](../basis.md) §II): each phase is a deterministic transition $E \mapsto E'$ from input artifact to output artifact, with validation gates implementing judgemental equality (§III) and the overall flow preserving functionality (§IV) — equal inputs to any phase produce equal outputs.

---

## II. Phase Primitives

### Phase 0: Bootstrap (Conditional)

**Purpose:** Discover template repositories in `{{TEMPLATES_DIR}}`, analyze, compose, and instantiate them into `{{CODE_DIR}}`, then generate a project profile. See [template-bootstrap.md](./template-bootstrap.md) for the full specification.

**Skip Condition:** This phase is **skipped** when:
- `{{CODE_DIR}}` is already populated with project files, AND
- A valid project profile exists in `.claude/profiles/`

When skipped, the orchestrator proceeds directly to Phase 1 (Preflight).

**Input Contract:**
```yaml
inputs:
  templates_dir: string              # Default: "templates" (from profile or convention)
  code_dir: string                   # Default: "code" (from profile or convention)
  project_name: string               # User-provided or inferred from first template
  placeholder_overrides: object      # Optional: user-provided placeholder values
```

**Transition Rules:**
```yaml
states:
  - idle
  - discovering_templates
  - analyzing_templates
  - resolving_composition
  - awaiting_user_resolution
  - instantiating
  - generating_profile
  - running_setup
  - validating
  - success
  - failure
  - skipped

transitions:
  - {from: idle, event: start, to: discovering_templates}
  - {from: idle, event: code_dir_populated, to: skipped}
  - {from: discovering_templates, event: templates_found, to: analyzing_templates}
  - {from: discovering_templates, event: no_templates, to: failure}
  - {from: analyzing_templates, event: analysis_complete, to: resolving_composition}
  - {from: analyzing_templates, event: unrecognized_template, to: failure}
  - {from: resolving_composition, event: no_conflicts, to: instantiating}
  - {from: resolving_composition, event: conflicts_detected, to: awaiting_user_resolution}
  - {from: awaiting_user_resolution, event: user_resolved, to: instantiating}
  - {from: instantiating, event: copy_complete, to: generating_profile}
  - {from: instantiating, event: copy_failed, to: failure}
  - {from: generating_profile, event: profile_generated, to: running_setup}
  - {from: running_setup, event: setup_complete, to: validating}
  - {from: running_setup, event: setup_failed, to: failure}
  - {from: validating, event: precheck_pass, to: success}
  - {from: validating, event: precheck_fail, to: failure}
```

**Process:**
1. **Discover**: Scan `.claude/context/` for subdirectories containing template repos
2. **Analyze**: Read `.harness-kit-template.yaml` manifest or infer language/toolchain/layer from file markers
3. **Compose**: Map templates to polyglot component layers, detect conflicts (user resolves if needed)
4. **Instantiate**: Copy template files into the project root, substituting `{{PLACEHOLDER}}` tokens
5. **Generate Profile**: Produce `.claude/profiles/<project>.yaml` from aggregated template metadata
6. **Setup**: Run post-instantiation commands (e.g., `npm install`, `uv sync`)
7. **Validate**: Verify project root is populated, profile is valid, precheck passes

**Output:**
```json
{
  "status": "success" | "failure" | "skipped",
  "templates_discovered": 2,
  "composition": {
    "is_polyglot": true,
    "layers": ["core", "ui"],
    "conflicts_resolved": []
  },
  "instantiation": {
    "files_written": 47,
    "placeholders_substituted": {"PROJECT_NAME": "my-project"}
  },
  "profile_generated": ".claude/profiles/my-project.yaml",
  "setup_results": [
    {"command": "cargo fetch", "layer": "core", "exit_code": 0},
    {"command": "pnpm install", "layer": "ui", "exit_code": 0}
  ],
  "validation": {
    "code_dir_populated": true,
    "profile_valid": true,
    "precheck_passed": true
  },
  "timestamp": "2026-02-17T10:00:00Z"
}
```

**Error as Data:**
```json
{
  "status": "failure",
  "error": {
    "code": "LAYER_CONFLICT",
    "message": "Templates 'python-agent' and 'data-pipeline' both claim layer 'agentic'",
    "context": {"templates": ["python-agent", "data-pipeline"], "layer": "agentic"}
  }
}
```

---

### Phase 1: Preflight

**Purpose:** Validate that the system is ready to begin work.

**Input Contract:**
```yaml
inputs:
  ticket_id: string              # Must exist in {{TASK_TODO_DIR}}
  project_profile: ProjectProfile  # Validated schema
  working_branch: string         # Optional: SCM branch name
```

**Transition Rules:**
```yaml
states:
  - idle
  - validating_ticket
  - validating_toolchain
  - validating_environment
  - success
  - failure
  
transitions:
  - {from: idle, event: start, to: validating_ticket}
  - {from: validating_ticket, event: valid, to: validating_toolchain}
  - {from: validating_ticket, event: invalid, to: failure}
  - {from: validating_toolchain, event: all_commands_executable, to: validating_environment}
  - {from: validating_toolchain, event: command_missing, to: failure}
  - {from: validating_environment, event: precheck_pass, to: success}
  - {from: validating_environment, event: precheck_fail, to: failure}
```

**Validation Rules:**
1. **Ticket Exists**: `{{TASK_TODO_DIR}}/{{ticket_id}}.json` is readable
2. **Ticket Schema**: JSON validates against [ticket schema](./ticket-lifecycle.md)
3. **Ticket State**: `state == "refined"`
4. **Toolchain Ready**: All `profile.toolchain.*_cmd` are executable
5. **Environment Clean**: `profile.toolchain.precheck_cmd` exits 0

**Output:**
```json
{
  "status": "success" | "failure",
  "ticket": {...},                      // Loaded ticket object
  "profile_snapshot": {...},            // Profile used for this run
  "precheck_output": "...",             // Stdout/stderr from precheck
  "timestamp": "2026-02-15T10:00:00Z"
}
```

**Error as Data:**
```json
{
  "status": "failure",
  "error": {
    "code": "TOOLCHAIN_MISSING",
    "message": "Command 'cargo' not found in PATH",
    "context": {"missing_command": "cargo", "path": "/usr/bin:/usr/local/bin"}
  }
}
```

---

### Phase 2: Planning

**Purpose:** Decompose the ticket into a sequence of concrete implementation steps.

**Input Contract:**
```yaml
inputs:
  ticket: Ticket                 # From preflight
  project_profile: ProjectProfile
  codebase_context: string       # Optional: relevant files/symbols
```

**Process:**
1. **Analyze Ticket**: LLM reads acceptance criteria and description
2. **Identify Touchpoints**: Which files/modules need changes
3. **Sequence Steps**: Order operations (e.g., add test fixtures before implementation)
4. **Estimate Scope**: Classify as `minimal`, `moderate`, `extensive`

**Output:**
```json
{
  "status": "success",
  "plan": {
    "scope": "moderate",
    "steps": [
      {
        "id": 1,
        "action": "Add RetryConfig struct to src/http/config.rs",
        "type": "code_addition",
        "estimated_lines": 25,
        "dependencies": []
      },
      {
        "id": 2,
        "action": "Implement exponential backoff with jitter",
        "type": "code_addition",
        "estimated_lines": 40,
        "dependencies": [1]
      },
      {
        "id": 3,
        "action": "Add unit tests for retry logic",
        "type": "test_addition",
        "estimated_lines": 100,
        "dependencies": [2]
      },
      {
        "id": 4,
        "action": "Update public API documentation",
        "type": "docs_update",
        "estimated_lines": 20,
        "dependencies": [1, 2]
      }
    ],
    "affected_files": [
      "src/http/config.rs",
      "src/http/client.rs",
      "tests/retry_tests.rs",
      "docs/http-client.md"
    ]
  }
}
```

---

### Phase 3: Iteration

**Purpose:** Execute plan steps with immediate feedback loop.

**Input Contract:**
```yaml
inputs:
  plan: Plan                     # From planning phase
  project_profile: ProjectProfile
  max_iterations: int            # From profile.governance.max_fix_iterations
```

**Transition Rules:**
```yaml
states:
  - idle
  - executing_step
  - validating_change
  - applying_change
  - success
  - failure
  - blocked
  
loop: |
  for each step in plan.steps:
    execute_step → validate_change → apply_change
  if all steps succeed: success
  if any step fails unrecoverably: blocked
  if retry budget exhausted: failure
```

**Process (per step):**
1. **Execute Step**: LLM generates code/docs changes
2. **Validate Change**:
   - Run `profile.toolchain.format_cmd` (auto-fix formatting)
   - Run `profile.toolchain.lint_cmd` (check for new warnings)
   - Run `profile.toolchain.test_cmd_targeted "{affected_tests}"` (immediate feedback)
3. **Apply Change**: If validation passes, commit change to working state
4. **Rollback**: If validation fails and not auto-fixable, revert and mark step as blocked

**Output:**
```json
{
  "status": "success" | "failure" | "blocked",
  "steps_completed": [1, 2, 3, 4],
  "steps_failed": [],
  "total_changes": {
    "files_modified": 4,
    "lines_added": 185,
    "lines_removed": 12
  },
  "validation_summary": {
    "format_issues_auto_fixed": 3,
    "lint_warnings": 0,
    "targeted_tests_passed": 12,
    "targeted_tests_failed": 0
  }
}
```

---

### Phase 4: Testing

**Purpose:** Comprehensive validation (focused → broad).

**Input Contract:**
```yaml
inputs:
  changes: ChangeSet             # From iteration phase
  project_profile: ProjectProfile
```

**Sub-Phases:**

#### 4a. Focused Testing
Run tests directly related to changes:
```bash
{{profile.toolchain.test_cmd_targeted}} "{{affected_test_patterns}}"
```

#### 4b. Broad Regression
Run full test suite:
```bash
{{profile.toolchain.test_cmd_full}}
```

**Transition Rules:**
```yaml
transitions:
  - {from: idle, to: focused_testing}
  - {from: focused_testing, event: all_pass, to: broad_regression}
  - {from: focused_testing, event: failures, to: analyzing_failures}
  - {from: broad_regression, event: all_pass, to: success}
  - {from: broad_regression, event: failures, to: analyzing_failures}
  - {from: analyzing_failures, event: fixable, to: applying_fixes}
  - {from: analyzing_failures, event: unfixable, to: blocked}
  - {from: applying_fixes, to: focused_testing}  # Retry loop
```

**Validation Rules:**
1. **Skip Policy**: Apply `profile.governance.skip_policy` (fail | warn | allow)
2. **Xfail Policy**: Apply `profile.governance.xfail_policy`
3. **Iteration Bound**: Max `profile.governance.max_fix_iterations` attempts

**Output:**
```json
{
  "status": "success" | "blocked",
  "focused_tests": {
    "total": 12,
    "passed": 12,
    "failed": 0,
    "skipped": 0,
    "duration_ms": 850
  },
  "regression_tests": {
    "total": 347,
    "passed": 347,
    "failed": 0,
    "skipped": 2,
    "duration_ms": 12400
  },
  "fix_iterations": [
    {"iteration": 1, "failures": 1, "fix_applied": "Added missing import", "result": "success"}
  ]
}
```

See [test-adapter.md](./test-adapter.md) for details on test execution interface.

---

### Phase 5: Review

**Purpose:** Multi-lens quality assessment by configured review agents.

**Input Contract:**
```yaml
inputs:
  changes: ChangeSet             # Diff of all changes
  ticket: Ticket                 # Original requirements
  project_profile: ProjectProfile
```

**Process:**
1. **Load Review Graph**: Read `profile.review_graph.agents` and `profile.review_graph.batches`
2. **Execute Batches**:
   - For each batch (in order):
     - Run all agents in batch (parallel if `batch.parallel == true`)
     - Wait for all agents to complete
     - Collect findings
     - If `batch.blocking == true` and critical findings exist, abort
3. **Merge Findings**: Apply `profile.review_graph.merge_strategy` to deduplicate

**Output:**
```json
{
  "status": "success" | "blocked",
  "batches_completed": 2,
  "findings": [
    {
      "id": "FIND-001",
      "agent_id": "correctness_spec",
      "severity": "high",
      "category": "specification_violation",
      "message": "Function does not handle edge case mentioned in AC #3",
      "location": {"file": "src/http/client.rs", "line": 45},
      "confidence": 0.85,
      "suggested_fix": "Add check for empty retry list",
      "auto_fixable": false
    }
  ],
  "summary": {
    "total_findings": 3,
    "by_severity": {"critical": 0, "high": 1, "medium": 2, "low": 0},
    "by_agent": {"correctness_spec": 1, "quality_structural": 2}
  }
}
```

See [review-rubrics.md](./review-rubrics.md) and [finding-schema.md](./finding-schema.md) for details.

---

### Phase 6: Triage

**Purpose:** Process findings and apply auto-fixes where appropriate.

**Input Contract:**
```yaml
inputs:
  findings: Finding[]            # From review phase
  project_profile: ProjectProfile
```

**Process:**
1. **Classify Findings**: Apply `profile.governance.autofix_confidence_rules`
2. **Group by Auto-Fixability**:
   - `apply_automatically`: Fix without user confirmation
   - `apply_with_user_confirmation`: Present fix, await approval
   - `suggest_only`: Log finding, no automatic action
3. **Execute Auto-Fixes**: For approved fixes, apply changes and re-run tests
4. **Verify Fix Efficacy**: Ensure fix resolves finding without breaking tests

**Output:**
```json
{
  "status": "success" | "blocked",
  "findings_processed": 3,
  "auto_fixes_applied": 2,
  "pending_user_review": 1,
  "fixes": [
    {
      "finding_id": "FIND-002",
      "action": "applied_automatically",
      "changes": "Added null check in retry logic",
      "verification": "re_ran_targeted_tests",
      "result": "success"
    }
  ]
}
```

---

### Phase 7: Closure

**Purpose:** Finalize artifacts, update ticket, and prepare handoff.

**Input Contract:**
```yaml
inputs:
  ticket: Ticket
  all_phase_outputs: PhaseResult[]  # Collected outputs from phases 1-6
  project_profile: ProjectProfile
```

**Process:**
1. **Generate Artifacts**:
   - **Diff Summary**: `{{ticket_id}}_diff.md` (human-readable changes)
   - **Test Report**: `{{ticket_id}}_test_run.json` (structured test results)
   - **Review Report**: `{{ticket_id}}_review_consolidated.json` (merged findings)
   - **Session Summary**: `{{ticket_id}}_summary.json` (end-to-end metrics)
2. **Update Ticket**:
   - Set `state = "done"`
   - Mark all `acceptance_criteria[].met = true` (with evidence links)
   - Append `artifacts` array with generated outputs
3. **Move Files**: Relocate ticket from `{{TASK_TODO_DIR}}` to `{{TASK_COMPLETED_DIR}}`
4. **Update Tracker**: Append transition event to `profile.layout.tracker_file`

**Output:**
```json
{
  "status": "success",
  "ticket_final_state": "done",
  "artifacts": [
    {"type": "code_change", "path": ".claude/artifacts/FEAT-123_diff.md"},
    {"type": "test_run", "path": ".claude/artifacts/FEAT-123_test_run.json"},
    {"type": "review_report", "path": ".claude/artifacts/FEAT-123_review_consolidated.json"},
    {"type": "summary", "path": ".claude/artifacts/FEAT-123_summary.json"}
  ],
  "metrics": {
    "total_duration_ms": 650000,
    "files_changed": 4,
    "lines_added": 185,
    "lines_removed": 12,
    "tests_added": 12,
    "review_findings": 3,
    "auto_fixes_applied": 2
  }
}
```

---

## III. Orchestration Flow (Simplified)

```
┌──────────────┐
│  Bootstrap   │  ← Phase 0 (conditional: skipped if project root populated)
│  (Phase 0)   │
└──────┬───────┘
       │ success / skipped
       ▼
┌─────────────┐
│  Preflight  │
└──────┬──────┘
       │ success
       ▼
┌─────────────┐
│  Planning   │
└──────┬──────┘
       │ plan ready
       ▼
┌─────────────┐
│  Iteration  │◄──┐
└──────┬──────┘   │ retry
       │ changes   │ (bounded)
       ▼           │
┌─────────────┐   │
│   Testing   │───┘
└──────┬──────┘
       │ all pass
       ▼
┌─────────────┐
│   Review    │
└──────┬──────┘
       │ findings
       ▼
┌─────────────┐
│   Triage    │
└──────┬──────┘
       │ resolved
       ▼
┌─────────────┐
│   Closure   │
└──────┬──────┘
       │
       ▼
    [DONE]
```

**Error Handling:**
- Any phase can transition to `blocked` state (requires user intervention)
- Failures propagate with full context (error as data)
- Partial progress is preserved (artifacts generated up to failure point)

---

## IV. Composition Primitives

### Sequential Composition

```python
def run_workflow(ticket_id, profile, templates_dir="templates", code_dir="code"):
    # Phase 0: Bootstrap (conditional)
    bootstrap_result = bootstrap(templates_dir, code_dir, profile)
    if bootstrap_result.status == "failure":
        return bootstrap_result
    if bootstrap_result.status == "success":
        profile = bootstrap_result.profile  # Use generated profile

    # Phase 1-7: Standard workflow
    result = preflight(ticket_id, profile)
    if not result.success: return result
    
    result = planning(result.ticket, profile)
    if not result.success: return result
    
    result = iteration(result.plan, profile)
    if not result.success: return result
    
    result = testing(result.changes, profile)
    if not result.success: return result
    
    result = review(result.changes, result.ticket, profile)
    if not result.success: return result
    
    result = triage(result.findings, profile)
    if not result.success: return result
    
    return closure(result.ticket, all_results, profile)
```

### Conditional Branching

```python
def review_phase(changes, ticket, profile):
    if not profile.review_graph.enabled:
        return PhaseResult(status="success", findings=[], skipped=True)
    
    return execute_review_graph(changes, ticket, profile)
```

### Retry Loop

```python
def testing_with_retry(changes, profile):
    for iteration in range(profile.governance.max_fix_iterations):
        result = run_tests(changes, profile)
        if result.all_pass:
            return PhaseResult(status="success", result=result)
        
        fix_result = apply_fixes(result.failures, profile)
        if not fix_result.fixable:
            return PhaseResult(status="blocked", reason="unfixable_failures")
        
        changes = apply_changes(fix_result.fixes)
    
    return PhaseResult(status="failure", reason="max_iterations_exceeded")
```

---

## V. Parameterization by Profile

Every phase primitive uses profile tokens:

| Phase | Profile Dependencies |
|-------|---------------------|
| Bootstrap | `layout.templates_dir`, `layout.code_dir`, `extensions.bootstrap` |
| Preflight | `layout.task_todo_dir`, `toolchain.precheck_cmd` |
| Planning | `layout.src_paths`, `layout.test_paths` |
| Iteration | `toolchain.format_cmd`, `toolchain.lint_cmd`, `governance.max_fix_iterations` |
| Testing | `toolchain.test_cmd_full`, `toolchain.test_cmd_targeted`, `governance.skip_policy` |
| Review | `review_graph.agents`, `review_graph.batches`, `review_graph.merge_strategy` |
| Triage | `governance.autofix_confidence_rules` |
| Closure | `layout.task_completed_dir`, `layout.artifact_output_dir`, `layout.tracker_file` |
| All Phases | `extensions.observability.*` (when enabled: trace context, sensitivity, identity) |

**No hardcoded assumptions** about language, toolchain, or file structure.

---

## VI. Observability — REDACTED Integration

When `profile.extensions.observability.enabled` is true and `provider` is `"agentaware"`, the phase orchestrator emits **REDACTED telemetry**. See [observability-standard.md](./observability-standard.md) for the full instrumentation specification.

### Root Trace

One trace is created per workflow execution (per ticket). The trace persists across all phases:

```python
import agentaware as aa
from agentaware import agent_call, tool_call

# Initialize REDACTED at orchestrator startup
aa.init(
    app_id=profile.extensions.observability.identity.app_id,
    agent_id="orchestrator",
    default_sensitive_data_type=profile.extensions.observability.sensitivity.default_type,
)

# Create root trace for the workflow
root_ctx = aa.TraceContext(
    user_id=invoking_user,
    correlation_id=ticket_id,         # Ticket ID serves as correlation_id
    session_id=workflow_session_id,    # Optional
    metadata={"root_name": f"workflow/{ticket_id}"},
)
```

### Phase-Level Spans

Each phase creates an `agent` span under the root trace:

```python
def execute_phase_with_telemetry(phase_name, phase_fn, profile, root_ctx, **kwargs):
    with agent_call(
        f"phase/{phase_name}",
        trace_context=root_ctx,
        input_data={"ticket_id": ticket_id, "phase": phase_name},
    ) as phase_span:
        result = phase_fn(profile=profile, **kwargs)
        phase_span.set_output({
            "status": result.status,
            "duration_ms": result.duration_ms,
        })
    return result
```

### Per-Phase Span Mapping

| Phase | Span Type | `agent_id` | Contains |
|-------|-----------|------------|----------|
| Bootstrap | `agent` | `"bootstrap"` | `chain` spans for discover/analyze/instantiate |
| Preflight | `agent` | `"preflight"` | `tool` span for precheck command |
| Planning | `agent` | `"planner"` | `generation` span for LLM decomposition |
| Iteration | `agent` | `"implementer"` | `generation` spans (code gen), `tool` spans (format/lint/test) |
| Testing | `agent` | `"test-runner"` | `tool` spans for focused and regression tests |
| Review | `chain` | `"review-orchestrator"` | Nested `agent` spans per review agent |
| Triage | `agent` | `"triager"` | `tool` spans for auto-fix application |
| Closure | `agent` | `"closure"` | Artifact generation metadata |

### Subagent Delegation Spans

When the supervisor delegates to a subagent (supervisor mode), each delegation creates a nested `agent` span with the subagent's own `agent_id`:

```python
with agent_call(
    f"subagent/{agent_id}",
    trace_context=root_ctx,
    input_data={"step": step_description, "phase": phase_name},
) as agent_span:
    result = await delegate(request)
    agent_span.set_output(result.artifacts)
```

### Toolchain Command Spans

Toolchain commands (test, lint, format, precheck) are `tool` spans:

```python
with tool_call(
    f"cmd/{command_name}",
    trace_context=root_ctx,
    input_data={"command": cmd, "cwd": working_dir},
) as cmd_span:
    result = execute_command(cmd, cwd=working_dir)
    cmd_span.set_output({
        "exit_code": result.exit_code,
        "stdout_preview": result.stdout[:500],
    })
```

### Review Agent Spans

Review phase creates a `chain` span containing parallel `agent` spans per review lens:

```python
with agent_call("phase/review", trace_context=root_ctx) as review_span:
    for batch in review_graph.batches:
        for agent_config in batch.agents:
            with agent_call(
                f"review/{agent_config.id}",
                trace_context=root_ctx,
                input_data={"lens": agent_config.lens, "diff_size": diff_lines},
            ) as lens_span:
                findings = run_review_agent(agent_config, diff)
                lens_span.set_output({
                    "findings_count": len(findings),
                    "severities": Counter(f.severity for f in findings),
                })
```

### Sensitivity Classification

All orchestrator spans default to `profile.extensions.observability.sensitivity.default_type` (typically `INTERNAL`). Individual spans can override:

- **Review findings** containing source code snippets: `INTERNAL` with labels `["SOURCE_CODE"]`
- **Test output** with assertion details: `INTERNAL`
- **User code generation**: inherits from profile sensitivity
- **Toolchain output** (build logs): `INTERNAL`

### Structured Event Fallback

When REDACTED is not enabled (or as supplementary local logging), phases continue to emit structured JSON events:

```json
{
  "event": "phase_start",
  "phase": "testing",
  "ticket_id": "FEAT-123",
  "timestamp": "2026-02-15T14:00:00Z"
}

{
  "event": "phase_complete",
  "phase": "testing",
  "ticket_id": "FEAT-123",
  "status": "success",
  "duration_ms": 12400,
  "metrics": {"tests_run": 347, "tests_passed": 347},
  "timestamp": "2026-02-15T14:00:12Z"
}
```

These events complement (not replace) REDACTED traces. When observability is enabled, both are emitted.

---

## VII. Relationship to Commands

This orchestrator **implements** the logic of:
- [/do-task](../commands/do-task.md)
- [/run-tests-and-fix](../commands/run-tests-and-fix.md)

But **generalized** to:
- Accept any project profile
- Compose phases dynamically based on config
- Emit standardized artifacts for deterministic pipeline

**Migration Path:**
1. Keep existing commands as high-level wrappers
2. Delegate to phase orchestrator with project-specific profiles
3. Commands become thin adapters that load profiles and invoke orchestrator

---

## VIII. Delegation Primitives (Multi-Agent Mode)

When `profile.execution.mode == "supervisor"`, the orchestrator operates as a **coordinator** rather than **executor**, delegating phases to specialized subagents.

### Delegation Interface

```typescript
interface DelegationRequest {
  agent_id: string;                    // From profile.agents.*
  phase: string;                       // Current phase name
  description: string;                 // Human-readable task summary
  prompt: string;                      // Complete agent instructions
  context: {                           // Contextual data
    ticket: Ticket;
    profile: ProjectProfile;
    artifacts: Artifact[];             // From previous phases
    constraints: PhaseConstraints;
  };
  timeout_ms: number;                  // Max execution time
  callback_url?: string;               // Optional async callback
}

interface DelegationResponse {
  agent_id: string;
  status: "success" | "blocked" | "failure";
  artifacts: Artifact[];               // Phase outputs
  metadata: {
    duration_ms: number;
    iterations_used?: number;
    model_used: string;
  };
  error?: ErrorDetail;                 // If status != "success"
}
```

### Phase-to-Agent Mapping

| Phase | Delegation Strategy | Agent(s) | Parallelism |
|-------|---------------------|----------|-------------|
| Bootstrap | None (supervisor self) | - | Sequential (conditional) |
| Preflight | Single | validator | Sequential |
| Planning | Single | planner | Sequential |
| Iteration | Multiple (per step) | implementer | DAG-based parallel |
| Testing | Single (with sub-phases) | tester | Sequential |
| Review | Multiple (per lens) | reviewer_* | Batch-based parallel |
| Triage | Single | triager | Sequential |
| Closure | None (supervisor self) | - | N/A |

### Delegation Strategies

#### 1. Sequential Delegation (Preflight, Planning, Testing, Triage)

```python
def execute_sequential_phase(phase: Phase, profile: ProjectProfile) -> PhaseResult:
    agent = select_agent(phase.required_capabilities, profile.agents)
    
    request = DelegationRequest(
        agent_id=agent.id,
        phase=phase.name,
        prompt=render_template(agent.prompt_template, context={
            "phase_contract": phase.contract,
            "ticket": load_ticket(),
            "profile": profile
        }),
        timeout_ms=profile.execution.timeout_policies.get(f"{phase.name}_timeout_ms")
    )
    
    response = await delegate(request)
    
    if response.status != "success":
        return handle_blocking(response)
    
    return PhaseResult(
        status="success",
        artifacts=response.artifacts,
        metadata=response.metadata
    )
```

#### 2. DAG Parallel Delegation (Iteration Phase)

```python
def execute_dag_phase(plan: Plan, profile: ProjectProfile) -> PhaseResult:
    dag = build_dependency_graph(plan.steps)
    ready_steps = dag.roots()
    completed = []
    all_artifacts = []
    
    while ready_steps:
        # Fan out to multiple implementers in parallel
        requests = [
            DelegationRequest(
                agent_id="implementer",
                phase="iteration",
                description=f"Implement step {step.id}",
                prompt=render_step_prompt(step, completed_artifacts=all_artifacts),
                context={
                    "step": step,
                    "dependencies": [completed[dep_id] for dep_id in step.dependencies]
                },
                timeout_ms=profile.execution.timeout_policies.iteration_timeout_ms
            )
            for step in ready_steps
        ]
        
        # Execute in parallel (respects agent.max_concurrent)
        responses = await delegate_parallel(requests, max_concurrent=profile.agents.implementer.max_concurrent)
        
        # Check all succeeded
        for i, response in enumerate(responses):
            if response.status != "success":
                return handle_blocking(response, partial_artifacts=all_artifacts)
            
            completed.append(ready_steps[i])
            all_artifacts.extend(response.artifacts)
        
        # Find next ready steps
        ready_steps = dag.next_ready(completed)
    
    # Merge all step artifacts
    merged = merge_iteration_artifacts(all_artifacts)
    return PhaseResult(status="success", artifacts=[merged])
```

#### 3. Batch Parallel Delegation (Review Phase)

```python
def execute_batch_phase(profile: ProjectProfile) -> PhaseResult:
    review_graph = profile.review_graph
    all_findings = []
    
    for batch in review_graph.batches:
        batch_requests = []
        
        for agent_id in batch.agents:
            agent = profile.agents[agent_id]
            batch_requests.append(
                DelegationRequest(
                    agent_id=agent_id,
                    phase="review",
                    description=f"Review: {agent.capabilities[0]}",
                    prompt=render_template(agent.prompt_template, context={
                        "diff": load_artifact("diff.md"),
                        "ticket": load_ticket(),
                        "language": profile.identity.language
                    }),
                    timeout_ms=profile.execution.timeout_policies.review_timeout_ms
                )
            )
        
        # Execute batch (parallel if batch.parallel == true)
        if batch.parallel:
            responses = await delegate_parallel(batch_requests)
        else:
            responses = [await delegate(req) for req in batch_requests]
        
        # Collect findings
        for response in responses:
            if response.status == "success":
                findings = parse_findings(response.artifacts)
                all_findings.extend(findings)
        
        # Check blocking condition
        if batch.blocking:
            critical = [f for f in all_findings if f.severity in ["critical", "high"]]
            if critical:
                return PhaseResult(
                    status="blocked",
                    reason="blocking_review_findings",
                    findings=critical
                )
    
    # Deduplicate across all batches
    unique = deduplicate_findings(all_findings, strategy=review_graph.merge_strategy)
    return PhaseResult(status="success", artifacts=[{"findings": unique}])
```

### Agent Selection Logic

```python
def select_agent(required_capabilities: List[str], agent_registry: Dict[str, Agent]) -> Agent:
    """Select best agent for required capabilities"""
    candidates = [
        agent for agent in agent_registry.values()
        if any(cap in agent.capabilities for cap in required_capabilities)
    ]
    
    if not candidates:
        raise ValueError(f"No agent found with capabilities: {required_capabilities}")
    
    # Prioritize by: 1) exact capability match, 2) model rank, 3) availability
    return max(candidates, key=lambda a: (
        len(set(a.capabilities) & set(required_capabilities)),
        model_rank(a.model),
        -get_active_instances(a.id)
    ))
```

### Concurrency Control

```python
class AgentPoolManager:
    def __init__(self, profile: ProjectProfile):
        self.profile = profile
        self.active_instances = defaultdict(int)  # agent_id -> count
        self.lock = asyncio.Lock()
    
    async def acquire(self, agent_id: str) -> bool:
        """Try to acquire slot for agent (respects max_concurrent)"""
        async with self.lock:
            agent = self.profile.agents[agent_id]
            if self.active_instances[agent_id] < agent.max_concurrent:
                self.active_instances[agent_id] += 1
                return True
            return False
    
    async def release(self, agent_id: str):
        """Release agent slot"""
        async with self.lock:
            self.active_instances[agent_id] -= 1
```

### Checkpoint and Resume

When a phase blocks, supervisor saves checkpoint:

```json
{
  "checkpoint_id": "TASK-001_phase-4_testing",
  "timestamp": "2026-02-15T14:30:00Z",
  "phase": "testing",
  "completed_phases": ["preflight", "planning", "iteration"],
  "blocking_agent": "tester",
  "blocking_reason": "unfixable_test_failures",
  "partial_artifacts": [
    {"type": "plan", "path": ".claude/artifacts/TASK-001_plan.json"},
    {"type": "iteration", "path": ".claude/artifacts/TASK-001_iteration.json"},
    {"type": "test_run_partial", "path": ".claude/artifacts/TASK-001_test_run.json"}
  ],
  "resume_instructions": "Review failing tests and provide fix guidance, or adjust governance.skip_policy"
}
```

User can resume from checkpoint:
```python
def resume_workflow(checkpoint_id: str, user_input: dict) -> PhaseResult:
    checkpoint = load_checkpoint(checkpoint_id)
    
    # Apply user corrections
    apply_user_input(checkpoint.phase, user_input)
    
    # Resume from blocking phase
    return execute_phase(
        phase=checkpoint.phase,
        profile=checkpoint.profile,
        prior_artifacts=checkpoint.partial_artifacts
    )
```

### Observability for Delegated Workflows

```json
{"event": "delegation_start", "agent_id": "implementer", "phase": "iteration", "step_id": 2, "timestamp": "..."}
{"event": "delegation_complete", "agent_id": "implementer", "status": "success", "duration_ms": 45000, "timestamp": "..."}
{"event": "delegation_blocked", "agent_id": "tester", "phase": "testing", "reason": "unfixable_failures", "timestamp": "..."}
{"event": "phase_complete", "phase": "iteration", "total_agents_used": 3, "total_duration_ms": 78000, "timestamp": "..."}
```

### Configuration Example

Full supervisor mode profile:

```yaml
execution:
  mode: "supervisor"
  delegation_strategy: "phase_level"
  parallelism:
    max_parallel_agents: 10
    enable_step_parallelism: true
    enable_batch_parallelism: true
  checkpoint_strategy: "phase_boundary"

agents:
  planner:
    capabilities: ["planning"]
    model: "claude-sonnet-4"
    max_concurrent: 1
    prompt_template: ".claude/agents/planner.md"
  
  implementer:
    capabilities: ["code_generation"]
    model: "claude-sonnet-4"
    max_concurrent: 3
    prompt_template: ".claude/agents/implementer.md"
  
  tester:
    capabilities: ["test_execution"]
    model: "claude-sonnet-4"
    max_concurrent: 1
    prompt_template: ".claude/agents/test-runner.md"
  
  # ... other agents
```

---

This orchestrator ensures workflows are **modular**, **testable**, and **language-agnostic**, consistent with [workflow-contract.md](./workflow-contract.md) principles. When REDACTED observability is enabled, every phase emits distributed traces per the [observability-standard.md](./observability-standard.md) specification.
