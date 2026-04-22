# Dual-Output Artifact Contracts: Structured + Human-Readable

This specification defines **standardized artifact formats** emitted by each workflow phase. Every phase produces **both JSON (machine-readable) and Markdown (human-readable)** outputs with deterministic schemas for the external code generation pipeline.

---

## I. Overview

Each phase in the [phase orchestrator](./phase-orchestrator.md) generates artifacts that:

1. **Dual Format**: JSON for deterministic pipeline + Markdown for human review
2. **Versioned Schema**: Explicit `schema_version` field for compatibility
3. **Self-Contained**: Include all context needed for independent processing
4. **Link-Preserving**: Artifacts reference each other by stable IDs

**Artifact Naming Convention:**
```
{{ARTIFACT_DIR}}/{{TICKET_ID}}_{{PHASE_NAME}}.json
{{ARTIFACT_DIR}}/{{TICKET_ID}}_{{PHASE_NAME}}.md
```

Examples:
- `.claude/artifacts/FEAT-123_preflight.json`
- `.claude/artifacts/FEAT-123_test_run.json`
- `.claude/artifacts/FEAT-123_review_consolidated.md`

---

## II. Artifact Contracts by Phase

### Phase 1: Preflight

**JSON Schema:**
```json
{
  "schema_version": "preflight.v1",
  "ticket_id": "FEAT-123",
  "timestamp": "2026-02-15T10:00:00Z",
  "status": "success" | "failure",
  "validation": {
    "ticket_exists": true,
    "ticket_schema_valid": true,
    "ticket_state": "refined",
    "toolchain_ready": true,
    "precheck_passed": true
  },
  "ticket_snapshot": {...},        // Full ticket object at start
  "profile_snapshot": {...},       // Full profile used
  "precheck_output": {
    "command": "cargo check --all",
    "exit_code": 0,
    "stdout": "...",
    "stderr": "",
    "duration_ms": 3400
  },
  "errors": []                     // Empty if success, populated if failure
}
```

**Markdown Template:**
```markdown
# Preflight: {{TICKET_ID}}

**Status:** ✅ Success / ❌ Failure  
**Timestamp:** {{TIMESTAMP}}

---

## Validation Results

- ✅ Ticket exists and is in 'refined' state
- ✅ All toolchain commands are executable
- ✅ Precheck passed ({{PRECHECK_CMD}})

## Precheck Output

```
{{PRECHECK_OUTPUT}}
```

---

**Next Phase:** Planning
```

---

### Phase 2: Planning

**JSON Schema:**
```json
{
  "schema_version": "plan.v1",
  "ticket_id": "FEAT-123",
  "timestamp": "2026-02-15T10:05:00Z",
  "status": "success",
  "plan": {
    "scope": "moderate",
    "estimated_duration_minutes": 45,
    "steps": [
      {
        "id": 1,
        "action": "Add RetryConfig struct to src/http/config.rs",
        "type": "code_addition",
        "estimated_lines": 25,
        "dependencies": [],
        "rationale": "Central configuration type for retry behavior"
      }
    ],
    "affected_files": [
      "src/http/config.rs",
      "src/http/client.rs",
      "tests/retry_tests.rs"
    ],
    "risk_assessment": "low"
  }
}
```

**Markdown Template:**
```markdown
# Implementation Plan: {{TICKET_ID}}

**Scope:** {{SCOPE}}  
**Estimated Duration:** {{DURATION}} minutes  
**Risk:** {{RISK}}

---

## Affected Files

{{#each affected_files}}
- {{this}}
{{/each}}

---

## Implementation Steps

{{#each steps}}
### Step {{id}}: {{action}}

- **Type:** {{type}}
- **Estimated Lines:** {{estimated_lines}}
- **Dependencies:** {{#if dependencies}}{{dependencies}}{{else}}None{{/if}}
- **Rationale:** {{rationale}}

{{/each}}

---

**Next Phase:** Iteration
```

---

### Phase 3: Iteration

**JSON Schema:**
```json
{
  "schema_version": "iteration.v1",
  "ticket_id": "FEAT-123",
  "timestamp": "2026-02-15T10:30:00Z",
  "status": "success" | "blocked",
  "steps_completed": [1, 2, 3, 4],
  "steps_failed": [],
  "iterations": [
    {
      "iteration": 1,
      "step_id": 1,
      "changes": {
        "files_modified": ["src/http/config.rs"],
        "lines_added": 27,
        "lines_removed": 2
      },
      "validation": {
        "format_passed": true,
        "lint_passed": true,
        "targeted_tests_passed": true
      },
      "duration_ms": 8500
    }
  ],
  "total_changes": {
    "files_modified": 4,
    "lines_added": 185,
    "lines_removed": 12
  },
  "diff_path": ".claude/artifacts/FEAT-123_diff.md"
}
```

**Markdown Template:**
```markdown
# Implementation Iteration: {{TICKET_ID}}

**Status:** {{STATUS}}  
**Steps Completed:** {{STEPS_COMPLETED.length}} / {{STEPS_TOTAL}}

---

## Changes Summary

- **Files Modified:** {{TOTAL_CHANGES.files_modified}}
- **Lines Added:** {{TOTAL_CHANGES.lines_added}}
- **Lines Removed:** {{TOTAL_CHANGES.lines_removed}}

---

## Iteration Log

{{#each iterations}}
### Iteration {{iteration}} (Step {{step_id}})

**Changes:**
- Modified: {{changes.files_modified}}
- +{{changes.lines_added}} / -{{changes.lines_removed}} lines

**Validation:**
- Format: {{#if validation.format_passed}}✅{{else}}❌{{/if}}
- Lint: {{#if validation.lint_passed}}✅{{else}}❌{{/if}}
- Tests: {{#if validation.targeted_tests_passed}}✅{{else}}❌{{/if}}

**Duration:** {{duration_ms}}ms

{{/each}}

---

**Full Diff:** [See diff](./{{TICKET_ID}}_diff.md)

---

**Next Phase:** Testing
```

---

### Phase 4: Testing

**JSON Schema:**
```json
{
  "schema_version": "test_run.v1",
  "ticket_id": "FEAT-123",
  "timestamp": "2026-02-15T10:45:00Z",
  "status": "success" | "blocked",
  "focused_tests": {
    "command": "cargo test retry_tests --",
    "total": 12,
    "passed": 12,
    "failed": 0,
    "skipped": 0,
    "xfailed": 0,
    "duration_ms": 850
  },
  "regression_tests": {
    "command": "cargo test --all",
    "total": 347,
    "passed": 347,
    "failed": 0,
    "skipped": 0,
    "xfailed": 0,
    "duration_ms": 12400
  },
  "policy_checks": {
    "skip_policy": "warn",
    "skip_count": 0,
    "xfail_policy": "allow",
    "xfail_count": 0,
    "gate_passed": true
  },
  "fix_iterations": [],
  "test_detail_path": ".claude/artifacts/FEAT-123_test_details.json"
}
```

**Markdown Template:**
```markdown
# Test Run: {{TICKET_ID}}

**Status:** ✅ All Tests Passed / ❌ Failures Detected  
**Timestamp:** {{TIMESTAMP}}

---

## Focused Tests

- **Total:** {{FOCUSED_TESTS.total}}
- **Passed:** {{FOCUSED_TESTS.passed}} ✅
- **Failed:** {{FOCUSED_TESTS.failed}}
- **Duration:** {{FOCUSED_TESTS.duration_ms}}ms

## Regression Tests

- **Total:** {{REGRESSION_TESTS.total}}
- **Passed:** {{REGRESSION_TESTS.passed}} ✅
- **Failed:** {{REGRESSION_TESTS.failed}}
- **Duration:** {{REGRESSION_TESTS.duration_ms}}ms

---

## Policy Checks

- **Skip Policy:** {{POLICY_CHECKS.skip_policy}} ({{POLICY_CHECKS.skip_count}} skipped)
- **Xfail Policy:** {{POLICY_CHECKS.xfail_policy}} ({{POLICY_CHECKS.xfail_count}} xfailed)
- **Gate Status:** {{#if POLICY_CHECKS.gate_passed}}✅ Passed{{else}}❌ Failed{{/if}}

{{#if fix_iterations.length}}
---

## Fix Iterations

{{#each fix_iterations}}
### Iteration {{iteration}}
- **Failures:** {{failures}}
- **Fix Applied:** {{fix_applied}}
- **Result:** {{result}}
{{/each}}
{{/if}}

---

**Next Phase:** Review
```

---

### Phase 5: Review

**JSON Schema:**
```json
{
  "schema_version": "review.v1",
  "ticket_id": "FEAT-123",
  "timestamp": "2026-02-15T11:00:00Z",
  "status": "success" | "blocked",
  "review_graph": {
    "agents_run": ["correctness_spec", "quality_structural", "docs_consistency"],
    "batches_completed": 2,
    "total_duration_ms": 45000
  },
  "findings": [
    // Array of findings conforming to finding.v1 schema
  ],
  "summary": {
    "total_findings": 5,
    "by_severity": {
      "critical": 0,
      "high": 1,
      "medium": 3,
      "low": 1
    },
    "by_category": {
      "missing_examples": 1,
      "deep_nesting": 1,
      "edge_case_missing": 1
    },
    "blocking_findings": 1
  },
  "deduplication": {
    "original_count": 7,
    "deduplicated_count": 5,
    "strategy": "deduplicate_by_location"
  }
}
```

**Markdown Template:**
```markdown
# Code Review: {{TICKET_ID}}

**Status:** {{#if summary.blocking_findings}}⚠️ Blocking Issues Found{{else}}✅ Clean{{/if}}  
**Timestamp:** {{TIMESTAMP}}

---

## Summary

- **Total Findings:** {{SUMMARY.total_findings}}
- **Critical:** {{SUMMARY.by_severity.critical}}
- **High:** {{SUMMARY.by_severity.high}}
- **Medium:** {{SUMMARY.by_severity.medium}}
- **Low:** {{SUMMARY.by_severity.low}}

---

## Review Graph

{{#each review_graph.agents_run}}
- {{this}}
{{/each}}

**Total Duration:** {{review_graph.total_duration_ms}}ms

---

## Findings

{{#each findings}}
### {{severity}} {{category}} ({{id}})

**Location:** [{{location.file}}:{{location.line}}]({{location.file}}#L{{location.line}})  
**Agent:** {{agent_id}}  
**Confidence:** {{confidence}}

{{message}}

{{#if suggested_fix}}
**Suggested Fix:**
{{suggested_fix.description}}

{{#if suggested_fix.auto_fixable}}
✅ Auto-fixable (risk: {{suggested_fix.risk}})
{{else}}
⚠️ Manual fix required
{{/if}}
{{/if}}

---

{{/each}}

---

**Next Phase:** Triage
```

---

### Phase 6: Triage

**JSON Schema:**
```json
{
  "schema_version": "triage.v1",
  "ticket_id": "FEAT-123",
  "timestamp": "2026-02-15T11:15:00Z",
  "status": "success" | "blocked",
  "findings_processed": 5,
  "auto_fixes_applied": 2,
  "pending_user_review": 1,
  "fixes": [
    {
      "finding_id": "FIND-A3F2B8C1",
      "action": "applied_automatically" | "apply_with_user_confirmation" | "suggest_only",
      "changes": {
        "files_modified": ["src/http/client.rs"],
        "lines_changed": 3
      },
      "verification": {
        "method": "re_ran_targeted_tests",
        "result": "success",
        "tests_run": 5,
        "tests_passed": 5
      }
    }
  ],
  "unresolved_findings": [
    "FIND-C5A8D3F1"
  ]
}
```

**Markdown Template:**
```markdown
# Triage: {{TICKET_ID}}

**Status:** {{STATUS}}  
**Timestamp:** {{TIMESTAMP}}

---

## Summary

- **Findings Processed:** {{findings_processed}}
- **Auto-Fixes Applied:** {{auto_fixes_applied}}
- **Pending User Review:** {{pending_user_review}}
- **Unresolved:** {{unresolved_findings.length}}

---

## Applied Fixes

{{#each fixes}}
### {{finding_id}}

**Action:** {{action}}  
**Changes:** {{changes.files_modified}}  
**Verification:** {{verification.method}} → {{verification.result}}

{{/each}}

---

{{#if unresolved_findings.length}}
## Unresolved Findings

{{#each unresolved_findings}}
- {{this}} (requires manual intervention)
{{/each}}
{{/if}}

---

**Next Phase:** Closure
```

---

### Phase 7: Closure

**JSON Schema:**
```json
{
  "schema_version": "closure.v1",
  "ticket_id": "FEAT-123",
  "timestamp": "2026-02-15T11:30:00Z",
  "status": "done",
  "ticket_final_state": "done",
  "artifacts": [
    {"type": "code_change", "path": ".claude/artifacts/FEAT-123_diff.md"},
    {"type": "test_run", "path": ".claude/artifacts/FEAT-123_test_run.json"},
    {"type": "review_report", "path": ".claude/artifacts/FEAT-123_review.json"},
    {"type": "summary", "path": ".claude/artifacts/FEAT-123_summary.json"}
  ],
  "metrics": {
    "total_duration_ms": 650000,
    "files_changed": 4,
    "lines_added": 185,
    "lines_removed": 12,
    "tests_added": 12,
    "tests_modified": 0,
    "review_findings": 5,
    "auto_fixes_applied": 2
  },
  "acceptance_criteria_status": [
    {"criterion": "Retry policy configurable per-request", "met": true, "evidence": "See RetryConfig in src/http/config.rs"},
    {"criterion": "Exponential backoff implemented", "met": true, "evidence": "See calculate_backoff() in src/http/retry.rs"}
  ]
}
```

**Markdown Template:**
```markdown
# Session Summary: {{TICKET_ID}}

**Status:** ✅ Done  
**Timestamp:** {{TIMESTAMP}}  
**Duration:** {{METRICS.total_duration_ms | format_duration}}

---

## Ticket: {{TICKET.title}}

{{TICKET.description}}

---

## Acceptance Criteria

{{#each acceptance_criteria_status}}
- [{{#if met}}x{{else}} {{/if}}] {{criterion}}
  {{#if evidence}}*Evidence:* {{evidence}}{{/if}}
{{/each}}

---

## Changes

- **Files Changed:** {{METRICS.files_changed}}
- **Lines Added:** {{METRICS.lines_added}}
- **Lines Removed:** {{METRICS.lines_removed}}
- **Tests Added:** {{METRICS.tests_added}}

---

## Quality Gates

- **All Tests Passed:** ✅
- **Review Findings:** {{METRICS.review_findings}} ({{METRICS.auto_fixes_applied}} auto-fixed)
- **No Blocking Issues:** ✅

---

## Artifacts

{{#each artifacts}}
- [{{type}}]({{path}})
{{/each}}

---

**Ticket moved to:** `{{TASK_COMPLETED_DIR}}/{{TICKET_ID}}.json`
```

---

### Example Objects (Cross-Phase)

**Purpose:** Explorable objects produced by tests, fixtures, or stories for use in the moldable canvas and hot-reload smoke validation. See [test-adapter.md](./test-adapter.md) §X (EDD), [moldable-canvas.md](./moldable-canvas.md) §IV (Example Object pattern), [component-model.md](./component-model.md) §VI (Examples).

**JSON Schema:**
```json
{
  "schema_version": "example.v1",
  "ticket_id": "TASK-001",
  "timestamp": "2026-02-15T10:30:00Z",
  "source_test_id": "tests::rate_limiter::test_token_bucket",
  "source_layer": "core",
  "object_type": "RateLimiter",
  "object_schema": {
    "version": "1.0.0",
    "fields": {
      "capacity": "u64",
      "fill_rate": "f64",
      "tokens": "f64"
    }
  },
  "serialized_value": "{\"capacity\":100,\"fill_rate\":10.0,\"tokens\":75.5}",
  "view_descriptors": [
    {
      "id": "default",
      "label": "Token Bucket State",
      "renderer": "json_tree"
    },
    {
      "id": "gauge",
      "label": "Fill Level",
      "renderer": "progress_bar",
      "params": {"field": "tokens", "max_field": "capacity"}
    }
  ],
  "provenance": {
    "ticket_id": "TASK-001",
    "trace_id": "abc123",
    "code_version": "a1b2c3d4",
    "generation_id": "gen-001"
  },
  "lineage": {
    "ticket_id": "TASK-001",
    "phase": "example",
    "depends_on": [],
    "produced_by": "test-runner"
  }
}
```

**Markdown Template:**
```markdown
# Example: {{OBJECT_TYPE}}

**Source:** `{{SOURCE_TEST_ID}}` ({{SOURCE_LAYER}} layer)  
**Schema Version:** {{OBJECT_SCHEMA.VERSION}}

## Value

```json
{{SERIALIZED_VALUE}}
```

## Views

{{#each VIEW_DESCRIPTORS}}
- **{{label}}** ({{renderer}})
{{/each}}

## Provenance

- Ticket: {{PROVENANCE.TICKET_ID}}
- Trace: {{PROVENANCE.TRACE_ID}}
- Code: {{PROVENANCE.CODE_VERSION}}
- Generation: {{PROVENANCE.GENERATION_ID}}
```

**Field Descriptions:**
- `schema_version`: Version identifier (`example.v1`)
- `ticket_id`: Associated ticket ID
- `timestamp`: ISO 8601 creation time
- `source_test_id`: Test, fixture, or story that produced the example
- `source_layer`: Layer identifier (e.g., `core`, `ui`, `agentic`)
- `object_type`: Type name of the serialized object
- `object_schema`: Schema metadata (version, field names and types)
- `serialized_value`: JSON-string representation of the object
- `view_descriptors`: Array of view configs (id, label, renderer, optional params)
- `provenance`: Trace, code version, and optional generation ID
- `lineage`: Links to workflow phase and producer

---

## III. Deterministic JSON Requirements

For pipeline compatibility, all JSON artifacts MUST:

1. **Stable Field Order**: Keys sorted lexicographically
2. **No Floating Timestamps in IDs**: Use deterministic hashing for IDs
3. **Explicit Nulls**: Use `null` instead of omitting fields
4. **Canonical Whitespace**: 2-space indentation, no trailing spaces
5. **UTF-8 Encoding**: With BOM stripped
6. **Schema Version Pin**: Exact version string (e.g., `"v1"`, not `"latest"`)

**Example:**
```json
{
  "schema_version": "test_run.v1",
  "status": "success",
  "ticket_id": "FEAT-123",
  "timestamp": "2026-02-15T10:45:00Z"
}
```
(Fields alphabetically sorted)

---

## IV. Artifact Lineage

Artifacts reference each other to form a **directed acyclic graph**:

```
preflight.json
    ↓
plan.json
    ↓
iteration.json ──→ diff.md
    ↓
test_run.json ──→ test_details.json
    ↓
review.json
    ↓
triage.json
    ↓
summary.json ──→ [all prior artifacts]
```

**Lineage Tracking:**
Each artifact includes `prior_artifacts` field:

```json
{
  "schema_version": "review.v1",
  "prior_artifacts": [
    ".claude/artifacts/FEAT-123_preflight.json",
    ".claude/artifacts/FEAT-123_plan.json",
    ".claude/artifacts/FEAT-123_iteration.json",
    ".claude/artifacts/FEAT-123_test_run.json"
  ]
}
```

---

## IV-A. Artifact Archiving

When a ticket reaches closure (Phase 7), all its artifacts and manifest are moved from the active directory to a per-ticket archive subdirectory:

**Active directory (in git):** `.claude/artifacts/`
**Archive directory (gitignored):** `.claude/artifacts-archive/TASK-NNN/`

### Archive Layout

```
.claude/artifacts-archive/
  TASK-001/
    TASK-001_manifest.json
    TASK-001_preflight.json
    TASK-001_preflight.md
    TASK-001_plan.json
    TASK-001_plan.md
    TASK-001_iteration.json
    TASK-001_iteration.md
    TASK-001_diff.md
    TASK-001_test_run.json
    TASK-001_test_run.md
    TASK-001_review.json
    TASK-001_review.md
    TASK-001_triage.json
    TASK-001_triage.md
    TASK-001_summary.json
    TASK-001_summary.md
  TASK-002/
    ...
```

### What Stays in Git

- `.claude/features/completed/TASK-NNN.json` — canonical ticket record
- `.claude/features/completed/TASK-NNN.md` — human-readable ticket summary
- `.claude/features/ticket_tracker.md` — tracker table with all ticket history

### What Gets Archived (Gitignored)

- All phase artifacts (`_preflight`, `_plan`, `_iteration`, `_test_run`, `_review`, `_triage`, `_summary`)
- The manifest file (`_manifest.json`)
- The diff file (`_diff.md`)

### Agent Access

Archived artifacts remain on disk and are readable by all agents. Commands like `/status` and `/resume-work` scan both the active and archive directories. The archive preserves the full audit trail without polluting git history.

---

## V. Validation Schema Files

Each artifact type has a corresponding JSON Schema file for validation:

```
.claude/specs/schemas/
  ├── preflight.v1.schema.json
  ├── plan.v1.schema.json
  ├── iteration.v1.schema.json
  ├── test_run.v1.schema.json
  ├── review.v1.schema.json
  ├── triage.v1.schema.json
  ├── closure.v1.schema.json
  └── finding.v1.schema.json
```

**Usage:**
```bash
# Validate artifact before passing to pipeline
jsonschema -i .claude/artifacts/FEAT-123_test_run.json \
           .claude/specs/schemas/test_run.v1.schema.json
```

---

## VI. Markdown Rendering Pipeline

Markdown artifacts are generated from JSON using **deterministic templates**:

```python
def render_markdown(artifact_json: dict, template_path: str) -> str:
    template = load_template(template_path)
    # Use deterministic template engine (Jinja2 with stable dict iteration)
    return template.render(artifact_json, sort_keys=True)
```

**Template Discovery:**
```
.claude/specs/templates/
  ├── preflight.md.j2
  ├── plan.md.j2
  ├── iteration.md.j2
  ├── test_run.md.j2
  ├── review.md.j2
  ├── triage.md.j2
  └── closure.md.j2
```

---

## VII. Benefits of Dual Output

1. **Machine Processing**: JSON for deterministic pipeline, schema validation, aggregation
2. **Human Review**: Markdown for quick reading, embedding in PRs, documentation
3. **Version Control Friendly**: Markdown diffs are readable; JSON provides stable keys
4. **Auditability**: Both formats together provide complete provenance
5. **Extensibility**: Add custom fields to JSON without breaking existing pipeline

---

This artifact contract ensures workflow outputs are **deterministic**, **versioned**, and **suitable for both human and machine consumption**, supporting the external code generation pipeline.
