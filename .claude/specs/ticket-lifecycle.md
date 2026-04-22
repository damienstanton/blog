# Generic Ticket Lifecycle: Language-Agnostic Task Management

This specification defines the **universal ticket/task lifecycle** for feature intake and tracking, abstracted from [/new-task](../commands/new-task.md) to work with any project $L$. It establishes the state machine, data schema, and refinement process independent of language/toolchain.

---

## I. Overview

A **ticket** represents a unit of work to be completed. The lifecycle governs:
- **States**: Where the ticket is in its journey (todo → refined → in_progress → done → blocked)
- **Data Schema**: Required/optional fields for tracking and verification
- **Transitions**: How tickets move between states
- **Refinement Gates**: Quality checks before work begins

All behavior is parameterized by the [project profile](./project-profile-schema.md).

---

## II. Ticket State Machine

Defined in `profile.lifecycle.states` and `profile.lifecycle.transitions`.

### Default States

```yaml
states:
  - name: "todo"
    label: "To Do"
    description: "Feature request captured, awaiting refinement"
    initial: true
    terminal: false
    
  - name: "refined"
    label: "Refined"
    description: "Requirements clarified, ready for implementation"
    terminal: false
    
  - name: "in_progress"
    label: "In Progress"
    description: "Agent is actively working on this ticket"
    terminal: false
    
  - name: "done"
    label: "Done"
    description: "All acceptance criteria met, implementation complete"
    terminal: true
    
  - name: "blocked"
    label: "Blocked"
    description: "Cannot proceed without external input"
    terminal: false
    requires_user: true
```

### Transitions

```yaml
transitions:
  - from: "todo"
    to: "refined"
    trigger: "refinement_complete"
    condition: "all_required_fields_present AND acceptance_criteria_valid"
    
  - from: "refined"
    to: "in_progress"
    trigger: "agent_start"
    condition: "profile_valid AND toolchain_ready"
    
  - from: "in_progress"
    to: "done"
    trigger: "all_gates_pass"
    condition: "tests_pass AND reviews_clean AND artifacts_generated"
    
  - from: "in_progress"
    to: "blocked"
    trigger: "gate_failure"
    condition: "failure_not_auto_recoverable"
    
  - from: "blocked"
    to: "in_progress"
    trigger: "user_unblock"
    condition: "user_provided_resolution"
    
  - from: "blocked"
    to: "todo"
    trigger: "requirements_changed"
    condition: "user_requests_restart"
```

### Invariants

1. **Single Initial State**: Exactly one state has `initial: true`
2. **Reachable Terminals**: All terminal states must be reachable from initial
3. **No Dead States**: Every non-terminal state has at least one outgoing transition
4. **Deterministic Triggers**: Each `(from_state, trigger)` pair maps to at most one `to_state`

---

## III. Ticket Data Schema

### Core Schema (JSON Schema)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["id", "title", "description", "state", "created_at"],
  "properties": {
    "id": {
      "type": "string",
      "pattern": "^[A-Z]+-\\d+$",
      "description": "Unique identifier (e.g., TASK-001, FEAT-042)"
    },
    "title": {
      "type": "string",
      "minLength": 5,
      "maxLength": 120,
      "description": "Concise summary of the work"
    },
    "description": {
      "type": "string",
      "minLength": 20,
      "description": "Detailed explanation of requirements, context, and constraints"
    },
    "state": {
      "type": "string",
      "enum": ["todo", "refined", "in_progress", "done", "blocked"],
      "description": "Current lifecycle state"
    },
    "created_at": {
      "type": "string",
      "format": "date-time",
      "description": "ISO 8601 timestamp of ticket creation"
    },
    "updated_at": {
      "type": "string",
      "format": "date-time",
      "description": "ISO 8601 timestamp of last modification"
    },
    "acceptance_criteria": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["criterion", "met"],
        "properties": {
          "criterion": {"type": "string"},
          "met": {"type": "boolean"},
          "evidence": {"type": "string"}
        }
      },
      "description": "Checklist of conditions that must be satisfied"
    },
    "definition_of_done": {
      "type": "array",
      "items": {"type": "string"},
      "description": "Project-specific quality gates (from profile.lifecycle.definition_of_done_checklist)"
    },
    "labels": {
      "type": "array",
      "items": {"type": "string"},
      "description": "Tags for categorization (e.g., 'bug', 'feature', 'refactor', 'docs')"
    },
    "priority": {
      "type": "string",
      "enum": ["low", "medium", "high", "critical"],
      "default": "medium"
    },
    "estimated_complexity": {
      "type": "string",
      "enum": ["trivial", "small", "medium", "large", "epic"],
      "description": "Rough scope estimate"
    },
    "assigned_to": {
      "type": "string",
      "description": "Agent or human identifier"
    },
    "blocked_reason": {
      "type": "string",
      "description": "Why ticket is blocked (required if state=blocked)"
    },
    "related_tickets": {
      "type": "array",
      "items": {"type": "string"},
      "description": "IDs of dependent or related tickets"
    },
    "artifacts": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["type", "path"],
        "properties": {
          "type": {"type": "string", "enum": ["code_change", "test_run", "review_report", "summary"]},
          "path": {"type": "string"},
          "schema_version": {"type": "string"}
        }
      },
      "description": "Generated outputs linked to this ticket"
    }
  }
}
```

### Required Fields by State

Validation rules that depend on current state:

| State | Required Beyond Core | Validation |
|-------|---------------------|------------|
| `todo` | None | Basic schema only |
| `refined` | `acceptance_criteria`, `definition_of_done` | Each AC must have non-empty `criterion` |
| `in_progress` | `assigned_to` | Must have valid agent/user ID |
| `done` | `artifacts` (at least one) | All AC `met=true`, artifact paths exist |
| `blocked` | `blocked_reason` | Must be non-empty string |

---

## IV. Ticket File Representation

Tickets are stored as **dual artifacts** (Markdown + JSON) in directories defined by `profile.layout.task_*_dir`.

### File Naming Convention

```
{{TASK_DIR}}/{{TICKET_ID}}.md
{{TASK_DIR}}/{{TICKET_ID}}.json
```

Examples:
- `.claude/features/todo/TASK-001.md` and `.claude/features/todo/TASK-001.json`
- `.claude/features/todo/FEAT-042.md` and `.claude/features/todo/FEAT-042.json` (state=refined)

### Markdown Template (Human-Readable)

Rendered from `profile.lifecycle.ticket_template`:

```markdown
# {{TICKET_ID}}: {{TITLE}}

**State:** {{STATE}}  
**Priority:** {{PRIORITY}}  
**Created:** {{CREATED_AT}}  
**Updated:** {{UPDATED_AT}}  

---

## Description

{{DESCRIPTION}}

---

## Acceptance Criteria

{{#each acceptance_criteria}}
- [{{#if met}}x{{else}} {{/if}}] {{criterion}}
  {{#if evidence}}*Evidence:* {{evidence}}{{/if}}
{{/each}}

---

## Definition of Done

{{#each definition_of_done}}
- [ ] {{this}}
{{/each}}

---

## Related Tickets

{{#each related_tickets}}
- [{{this}}](../{{this}}.md)
{{/each}}

---

## Artifacts

{{#each artifacts}}
- [{{type}}]({{path}}) (schema: {{schema_version}})
{{/each}}
```

### JSON Artifact (Machine-Readable)

Strict schema for deterministic pipeline:

```json
{
  "schema_version": "ticket.v1",
  "id": "TASK-001",
  "title": "Implement generic test adapter interface",
  "description": "...",
  "state": "refined",
  "created_at": "2026-02-15T10:30:00Z",
  "updated_at": "2026-02-15T11:45:00Z",
  "acceptance_criteria": [
    {
      "criterion": "Interface supports arbitrary test runners",
      "met": false,
      "evidence": null
    }
  ],
  "definition_of_done": [
    "All tests pass",
    "Code reviewed by at least 2 agents",
    "Documentation updated"
  ],
  "labels": ["feature", "testing"],
  "priority": "high",
  "estimated_complexity": "medium",
  "assigned_to": null,
  "blocked_reason": null,
  "related_tickets": [],
  "artifacts": []
}
```

---

## V. Refinement Process

Maps to [/new-task](../commands/new-task.md) intake loop.

### Phase 1: Capture (todo → refined)

**Input:** User feature request (natural language)

**Process:**
1. **Parse Request**: Extract title, description, implicit requirements
2. **Generate Draft**: LLM creates initial ticket with:
   - Plausible acceptance criteria (inferred from description)
   - Relevant labels (based on keywords)
   - Estimated complexity (based on scope signals)
3. **Validate Schema**: Check against `profile.lifecycle.required_fields`
4. **Write Files**: Save to `{{TASK_TODO_DIR}}/{{TICKET_ID}}.{md,json}`

**Output:** Ticket in `todo` state

### Phase 2: Refinement Q&A (todo → refined)

**Trigger:** User or agent initiates refinement

**Process:**
1. **Analyze Draft**: LLM reviews ticket for ambiguities:
   - Vague acceptance criteria
   - Missing context (e.g., "which module?")
   - Unspecified constraints (e.g., performance, compatibility)
2. **Generate Questions**: Batch clarifying questions (max 4 per round)
3. **User Responds**: Provide answers or additional context
4. **Update Ticket**: Incorporate responses into description and AC
5. **Repeat**: Continue Q&A until no critical ambiguities remain (max 3 rounds)
6. **Finalize**: Mark all required fields complete, transition to `refined` state
7. **Move Files**: Relocate to `{{TASK_REFINED_DIR}}/{{TICKET_ID}}.{md,json}`

**Output:** Ticket in `refined` state with complete, unambiguous AC

**Gate Criteria:**
- All `profile.lifecycle.required_fields` present
- Each AC has clear pass/fail condition (no subjective language like "good" or "better")
- Description includes relevant constraints (language-specific if applicable)
- No unresolved questions or "TBD" placeholders

---

## VI. Tracker File

Central state ledger at `profile.layout.tracker_file`.

### Format: JSON Lines (append-only log)

Each line is a standalone JSON object representing a state transition:

```jsonl
{"timestamp": "2026-02-15T10:30:00Z", "event": "ticket_created", "ticket_id": "TASK-001", "state": "todo"}
{"timestamp": "2026-02-15T11:45:00Z", "event": "transition", "ticket_id": "TASK-001", "from": "todo", "to": "refined", "trigger": "refinement_complete"}
{"timestamp": "2026-02-15T14:20:00Z", "event": "transition", "ticket_id": "TASK-001", "from": "refined", "to": "in_progress", "trigger": "agent_start", "assigned_to": "claude-sonnet-4"}
{"timestamp": "2026-02-15T16:00:00Z", "event": "artifact_added", "ticket_id": "TASK-001", "artifact": {"type": "test_run", "path": ".claude/artifacts/TASK-001_test_run.json"}}
{"timestamp": "2026-02-15T17:30:00Z", "event": "transition", "ticket_id": "TASK-001", "from": "in_progress", "to": "done", "trigger": "all_gates_pass"}
```

### Benefits

1. **Immutable Audit Trail**: Never overwrite; only append
2. **Point-in-Time Queries**: Reconstruct any past state by replaying log
3. **Diff-Friendly**: One event per line, easy to version control
4. **Deterministic**: Timestamp for audit only; event order is canonical

---

## VII. Language-Agnostic Considerations

### Avoiding Language Assumptions

**Bad (Python-specific):**
```markdown
## Acceptance Criteria
- [ ] Add pytest fixtures for new feature
- [ ] Update `setup.py` dependencies
```

**Good (Generic):**
```markdown
## Acceptance Criteria
- [ ] Add test fixtures for new feature (using project test framework)
- [ ] Update project dependency manifest ({{PKG_MANAGER}})
```

### Profile-Driven Templates

The ticket template should use tokens:

```markdown
## Definition of Done

{{#each profile.lifecycle.definition_of_done_checklist}}
- [ ] {{this}}
{{/each}}
```

So for Rust project:
- All tests pass (`cargo test`)
- Code formatted (`cargo fmt --check`)
- Linter clean (`cargo clippy`)

For Python project:
- All tests pass (`pytest`)
- Code formatted (`ruff format`)
- Type checks pass (`mypy`)

---

## VIII. Integration with Workflow Phases

### Create-Todos Command

```
User Input → Feature Intake Phase
  ├─ input_contract: feature_description (string)
  ├─ transition_rules: capture → refine → finalized
  └─ output: ticket.json + ticket.md in {{TASK_REFINED_DIR}}
```

### Implement-Todos Command

```
Ticket Selection → Implementation Phase
  ├─ input_contract: ticket_id (from refined), project_profile
  ├─ transition_rules: plan → code → test → review → done
  ├─ validation_rules: ticket.state == "refined", all required fields present
  └─ output: updates ticket with artifacts, moves to {{TASK_COMPLETED_DIR}}
```

---

## IX. Validation Strategy

Before accepting a ticket as `refined`:

1. **Schema Compliance**: JSON validates against ticket schema
2. **AC Specificity**: Each criterion has measurable/testable outcome
   - ❌ "Code should be clean"
   - ✅ "No linter warnings on changed files"
3. **Completeness**: All required fields non-empty
4. **Consistency**: Markdown and JSON have identical data (MD is derived from JSON source of truth)
5. **Reachability**: Ticket can transition to `done` via defined paths

---

## X. Example: End-to-End Flow

### Step 1: User Request
```
"Add support for custom retry policies in the HTTP client"
```

### Step 2: Draft Ticket (todo)
```json
{
  "id": "FEAT-123",
  "title": "Add custom retry policies to HTTP client",
  "description": "Enable users to configure retry behavior (max attempts, backoff strategy, retryable status codes) for HTTP requests.",
  "state": "todo",
  "acceptance_criteria": [
    {"criterion": "Users can specify max retry attempts", "met": false},
    {"criterion": "Support exponential backoff", "met": false},
    {"criterion": "Configurable retryable status codes", "met": false}
  ],
  "labels": ["feature", "http"],
  "priority": "medium",
  "estimated_complexity": "medium"
}
```

### Step 3: Refinement Questions
```
Q1: Should retry policy be per-client or per-request?
Q2: What default backoff strategy should we use?
Q3: Are there any status codes that should never retry (e.g., 4xx)?
```

### Step 4: User Answers
```
A1: Per-request, with option to set client-wide defaults
A2: Exponential with jitter, default multiplier 2.0
A3: Never retry 400, 401, 403, 404; always consider 5xx retryable
```

### Step 5: Refined Ticket
```json
{
  "id": "FEAT-123",
  "state": "refined",
  "description": "Enable per-request retry configuration with client-wide defaults. Use exponential backoff with jitter (multiplier 2.0). Never retry 4xx except 429; always retry 5xx.",
  "acceptance_criteria": [
    {"criterion": "Retry policy configurable per-request", "met": false},
    {"criterion": "Client has default retry policy field", "met": false},
    {"criterion": "Exponential backoff with jitter implemented", "met": false},
    {"criterion": "Status code classification: never retry [400,401,403,404], always retry [5xx]", "met": false},
    {"criterion": "Tests cover max retries exhaustion", "met": false},
    {"criterion": "Documentation includes example usage", "met": false}
  ],
  "definition_of_done": [
    "All tests pass",
    "Code reviewed by 2 agents",
    "API documentation updated",
    "No new linter warnings"
  ]
}
```

### Step 6: Implementation (→ in_progress → done)

Agent reads `FEAT-123.json`, implements feature, runs tests, generates artifacts, updates ticket:

```json
{
  "state": "done",
  "acceptance_criteria": [
    {"criterion": "Retry policy configurable per-request", "met": true, "evidence": "See RetryConfig struct in src/http.rs"},
    // ... all met=true
  ],
  "artifacts": [
    {"type": "code_change", "path": ".claude/artifacts/FEAT-123_diff.md"},
    {"type": "test_run", "path": ".claude/artifacts/FEAT-123_test_run.json"},
    {"type": "review_report", "path": ".claude/artifacts/FEAT-123_review_consolidated.json"}
  ]
}
```

---

## XI. Extension Points

### Custom States

Projects can add states beyond the default five:

```yaml
states:
  - {name: "todo", initial: true}
  - {name: "triaged"}           # Added: prioritization gate
  - {name: "refined"}
  - {name: "in_progress"}
  - {name: "in_review"}          # Added: separate review state
  - {name: "done", terminal: true}
  - {name: "rejected", terminal: true}  # Added: explicit rejection
```

### Custom Fields

Use `extensions` in profile:

```yaml
lifecycle:
  custom_fields:
    - name: "customer_impact"
      type: "enum"
      values: ["none", "low", "medium", "high", "critical"]
      required_states: ["refined", "in_progress", "done"]
```

---

This spec ensures ticket management is **deterministic**, **language-agnostic**, and **verifiable**, consistent with the [workflow contract](./workflow-contract.md) principles.
