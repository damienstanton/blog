# Project Profile Schema: Configure Workflow for Language $L$

This schema defines **all configurable parameters** needed to instantiate the universal [workflow contract](./workflow-contract.md) for a specific language/project $L$. A project profile is a **data file** (JSON/YAML) that provides concrete values for every token referenced by commands and agents.

---

## I. Profile Structure (JSON Schema)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["identity", "layout", "toolchain", "governance", "review_graph", "lifecycle"],
  "properties": {
    "identity": { "$ref": "#/definitions/Identity" },
    "layout": { "$ref": "#/definitions/Layout" },
    "toolchain": { "$ref": "#/definitions/Toolchain" },
    "governance": { "$ref": "#/definitions/Governance" },
    "review_graph": { "$ref": "#/definitions/ReviewGraph" },
    "lifecycle": { "$ref": "#/definitions/Lifecycle" },
    "execution": { "$ref": "#/definitions/Execution" },
    "agents": { "$ref": "#/definitions/Agents" },
    "extensions": { "$ref": "#/definitions/Extensions" }
  },
  "definitions": {
    "Identity": { /* ... */ },
    "Layout": { /* ... */ },
    "Toolchain": { /* ... */ },
    "Governance": { /* ... */ },
    "ReviewGraph": { /* ... */ },
    "Lifecycle": { /* ... */ },
    "Execution": { /* ... */ },
    "Agents": { /* ... */ },
    "Extensions": { /* ... */ }
  }
}
```

---

## II. Section Definitions

### 1. Identity (`identity`)

Basic project metadata.

```yaml
identity:
  project_name: "my-rust-lib"        # {{PROJECT_NAME}}
  language: "Rust"                    # {{LANGUAGE}}
  runtime: "native"                   # {{RUNTIME}} (native | vm | interpreted)
  project_root: "/path/to/project"    # {{PROJECT_ROOT}} (absolute)
  primary_package_manager: "cargo"    # For display/reporting only
```

**Fields:**
- `project_name`: Human-readable identifier
- `language`: Primary implementation language (used for syntax highlighting, heuristics)
- `runtime`: Execution model affects test/deploy strategy
- `project_root`: Absolute path to workspace root
- `primary_package_manager`: Informational (e.g., "cargo", "npm", "poetry")

---

### 2. Layout (`layout`)

Maps semantic locations to concrete paths (all relative to `project_root`).

```yaml
layout:
  code_dir: "."                       # {{CODE_DIR}} (project root; final output when bootstrapping)
  templates_dir: ".claude/context"            # {{TEMPLATES_DIR}} (template repositories)
  src_paths:                          # {{SRC_PATHS}}
    - "src/"
    - "lib/"
  test_paths:                         # {{TEST_PATHS}}
    - "tests/"
    - "src/**/test_*.rs"              # Supports globs
  doc_paths:                          # {{DOC_PATHS}}
    - "README.md"
    - "docs/"
    - "src/**/*.rs"                   # If docs are inline
  task_todo_dir: ".claude/features/todo"           # {{TASK_TODO_DIR}}
  task_completed_dir: ".claude/features/completed"  # {{TASK_COMPLETED_DIR}}
  tracker_file: ".claude/features/ticket_tracker.md"  # {{TRACKER_FILE}}
  artifact_output_dir: "artifacts"    # Where JSON/MD outputs go
```

**Fields:**
- `code_dir`: Directory where the final output project lives. When using template bootstrapping, the project root is populated from templates and all subsequent workflow phases operate here. `src_paths` and `test_paths` are relative to this directory when set. Default: `"."`
- `templates_dir`: Directory containing cloned template repositories (read-only references). Each subdirectory is one template. Default: `".claude/context"`. See [template-bootstrap.md](./template-bootstrap.md)
- `src_paths`: Patterns matching production code
- `test_paths`: Patterns matching test code
- `doc_paths`: User-facing documentation (inline or standalone)
- `task_*_dir`: Ticket lifecycle folders
- `tracker_file`: Central state tracking (append-only log or KV store)
- `artifact_output_dir`: Workflow step outputs (for deterministic pipeline ingestion)

---

### 3. Toolchain (`toolchain`)

Commands for common operations; all must be executable and exit with Posix semantics.

```yaml
toolchain:
  package_install_cmd: "cargo fetch"  # {{PKG_INSTALL_CMD}}
  precheck_cmd: "cargo check --all"   # {{PRECHECK_CMD}} (quick validation)
  
  test_cmd_full: "cargo test --all"   # {{TEST_CMD_FULL}} (entire suite)
  test_cmd_targeted: "cargo test {target}"  # {{TEST_CMD_TARGETED}} ({target} is placeholder)
  test_output_format: "cargo_json"    # {{TEST_OUTPUT_FORMAT}} (for parser selection)
  
  format_cmd: "cargo fmt --all"       # {{FORMAT_CMD}}
  lint_cmd: "cargo clippy --all"      # {{LINT_CMD}}
  
  build_cmd: "cargo build --release"  # {{BUILD_CMD}} (optional)
  clean_cmd: "cargo clean"            # {{CLEAN_CMD}} (optional)
```

**Fields:**
- `*_cmd`: Shell command strings; may include placeholders like `{target}`, `{file}`, `{test_name}`
- `test_output_format`: Hint for choosing parser (e.g., `"pytest_json"`, `"junit_xml"`, `"go_test"`)
- All commands MUST return 0 on success, non-zero on failure
- Commands SHOULD be deterministic (no network calls unless necessary and cached)

---

### 4. Governance (`governance`)

Policies controlling workflow behavior (gates, auto-actions, strictness).

```yaml
governance:
  skip_policy: "fail"                 # {{SKIP_POLICY}} (fail | warn | allow)
  xfail_policy: "fail"                # {{XFAIL_POLICY}} (fail | warn | allow)
  
  autofix_confidence_rules:           # {{AUTOFIX_CONFIDENCE_RULES}}
    - condition: "confidence >= 0.9 AND risk == 'low'"
      action: "apply_automatically"
    - condition: "confidence >= 0.7 AND risk == 'low'"
      action: "apply_with_user_confirmation"
    - condition: "default"
      action: "suggest_only"
  
  failure_classifier_rules:           # {{FAILURE_CLASSIFIER_RULES}}
    - pattern: "panic|segfault|core dumped"
      severity: "critical"
      category: "runtime_error"
    - pattern: "timeout|deadline exceeded"
      severity: "high"
      category: "performance"
    - pattern: "assertion failed|expected .* got"
      severity: "medium"
      category: "logic_error"
  
  rollback_on_failure: true           # Revert changes if any gate fails
  require_user_gate_for_risky: true   # Prompt before destructive actions
  max_fix_iterations: 3               # Bound remediation loops per workflow-contract.md
```

**Fields:**
- `skip_policy` / `xfail_policy`: How to treat skipped/expected-fail tests
- `autofix_confidence_rules`: Decision tree for when to apply fixes automatically
- `failure_classifier_rules`: Heuristics for categorizing test failures
- `rollback_on_failure`: Safety behavior
- `require_user_gate_for_risky`: Interactive confirmation gates
- `max_fix_iterations`: Termination guarantee (see [workflow-contract.md](./workflow-contract.md))

---

### 5. Review Graph (`review_graph`)

Defines which agents run, in what order, with what models.

```yaml
review_graph:
  enabled: true                       # {{REVIEW_ENABLED}}
  agents:                             # {{REVIEW_AGENTS}}
    - id: "correctness_spec"
      prompt_template: ".claude/agents/review-correctness-specification.md"
      model: "claude-sonnet-4"
      lens: "specification_adherence"
      batch: 1
    
    - id: "correctness_defensive"
      prompt_template: ".claude/agents/review-correctness-defensive.md"
      model: "claude-sonnet-4"
      lens: "runtime_safety"
      batch: 1
    
    - id: "quality_structural"
      prompt_template: ".claude/agents/review-quality-structural.md"
      model: "claude-sonnet-4"
      lens: "maintainability"
      batch: 2
    
    - id: "quality_structural_codex"
      prompt_template: ".claude/agents/review-quality-structural.md"  # codex merged; use profile model override
      model: "gpt-4"
      lens: "maintainability"
      batch: 2
    
    - id: "docs_consistency"
      prompt_template: ".claude/agents/review-docs-consistency.md"
      model: "claude-sonnet-4"
      lens: "documentation"
      batch: 2
  
  batches:                            # {{REVIEW_BATCHES}}
    - id: 1
      parallel: true                  # Run all batch 1 agents concurrently
      blocking: true                  # Must pass before batch 2
    - id: 2
      parallel: true
      blocking: false                 # Can have warnings, won't block merge
  
  merge_strategy: "deduplicate_by_location"  # How to combine findings from multiple agents
  finding_schema_version: "v1"        # References common finding schema
```

**Fields:**
- `agents`: List of review agents with prompt templates and model assignments
- `batches`: Execution topology (parallel/sequential, blocking/advisory)
- `merge_strategy`: Deduplication logic for overlapping findings
- `finding_schema_version`: Ensures compatibility with downstream pipeline

---

### 6. Lifecycle (`lifecycle`)

Ticket/task state machine and templates.

```yaml
lifecycle:
  ticket_template: ".claude/context/ticket.md"  # {{TASK_TEMPLATE}}
  
  states:                             # State machine definition
    - name: "todo"                    # {{STATUS_TODO}}
      label: "To Do"
      initial: true
      terminal: false
    - name: "refined"                 # {{STATUS_REFINED}}
      label: "Refined"
      terminal: false
    - name: "in_progress"
      label: "In Progress"
      terminal: false
    - name: "done"                    # {{STATUS_DONE}}
      label: "Done"
      terminal: true
    - name: "blocked"
      label: "Blocked"
      terminal: false
      requires_user: true
  
  transitions:
    - {from: "todo", to: "refined", trigger: "refinement_complete"}
    - {from: "refined", to: "in_progress", trigger: "agent_start"}
    - {from: "in_progress", to: "done", trigger: "all_gates_pass"}
    - {from: "in_progress", to: "blocked", trigger: "gate_failure"}
    - {from: "blocked", to: "in_progress", trigger: "user_unblock"}
  
  required_fields:                    # Ticket must have these
    - "title"
    - "description"
    - "acceptance_criteria"
    - "definition_of_done"
  
  acceptance_criteria_template: |
    - [ ] Functionality: ...
    - [ ] Tests: ...
    - [ ] Docs: ...
  
  definition_of_done_checklist:
    - "All tests pass"
    - "Code reviewed ({{REVIEW_AGENTS.length}} agents)"
    - "No new linter warnings"
    - "Documentation updated"
```

**Fields:**
- `ticket_template`: Markdown template for new tasks
- `states`: FSM states matching [workflow-contract.md](./workflow-contract.md) transition rules
- `transitions`: Allowed state changes
- `required_fields`: Schema validation for tickets
- `acceptance_criteria_template` / `definition_of_done_checklist`: User guidance

---

### 7. Execution (`execution`)

Controls orchestration mode and delegation strategy for multi-agent workflows.

```yaml
execution:
  mode: "supervisor"                  # {{EXECUTION_MODE}} (monolithic | supervisor)
  delegation_strategy: "phase_level"  # {{DELEGATION_STRATEGY}} (phase_level | step_level)
  
  parallelism:
    max_parallel_agents: 10           # System-wide concurrency limit
    enable_step_parallelism: true     # Allow parallel implementation steps
    enable_batch_parallelism: true    # Allow parallel review batches
  
  timeout_policies:
    default_phase_timeout_ms: 300000  # 5 minutes default
    preflight_timeout_ms: 30000       # 30 seconds
    planning_timeout_ms: 60000        # 1 minute
    iteration_timeout_ms: 600000      # 10 minutes
    testing_timeout_ms: 300000        # 5 minutes
    review_timeout_ms: 180000         # 3 minutes
    triage_timeout_ms: 120000         # 2 minutes
  
  checkpoint_strategy: "phase_boundary"  # When to save resume state (phase_boundary | step_boundary | never)
  resume_policy: "from_last_checkpoint"  # How to handle resume requests
```

**Execution Modes:**
- `monolithic`: Single agent executes all phases sequentially (default)
- `supervisor`: Main agent delegates phases/steps to specialized subagents

**Delegation Strategies:**
- `phase_level`: Delegate entire phases (e.g., all of Planning to planner agent)
- `step_level`: Delegate individual implementation steps (maximum parallelism)

**Fields:**
- `mode`: Orchestration model
- `delegation_strategy`: Granularity of work distribution
- `parallelism`: Concurrency limits and toggles
- `timeout_policies`: Per-phase timeouts to prevent hangs
- `checkpoint_strategy`: Resume support for long-running workflows
- `resume_policy`: Behavior when restarting blocked workflows

---

### 8. Agents (`agents`)

Registry of specialized subagents available for delegation (used when `execution.mode == "supervisor"`).

```yaml
agents:
  planner:
    capabilities: ["planning", "decomposition", "dependency_analysis"]
    model: "claude-sonnet-4"          # Model to use for this agent
    max_concurrent: 1                 # How many instances can run in parallel
    prompt_template: ".claude/agents/planner.md"
    timeout_override_ms: 60000        # Override default timeout
  
  implementer:
    capabilities: ["code_generation", "formatting", "linting"]
    model: "claude-sonnet-4"
    max_concurrent: 3                 # Can parallelize independent steps
    prompt_template: ".claude/agents/implementer.md"
  
  tester:
    capabilities: ["test_execution", "test_fixing", "test_analysis"]
    model: "claude-sonnet-4"
    max_concurrent: 1                 # Tests must run sequentially
    prompt_template: ".claude/agents/test-runner.md"
  
  reviewer_spec:
    capabilities: ["review_specification"]
    model: "claude-opus-4"            # Use more powerful model for critical reviews
    max_concurrent: 1
    prompt_template: ".claude/agents/review-correctness-specification.md"
  
  reviewer_safety:
    capabilities: ["review_safety", "review_defensive"]
    model: "claude-sonnet-4"
    max_concurrent: 1
    prompt_template: ".claude/agents/review-correctness-defensive.md"
  
  reviewer_maintainability:
    capabilities: ["review_structural", "review_evolutionary"]
    model: "claude-sonnet-4"
    max_concurrent: 2                 # Can run structural + evolutionary in parallel
    prompt_template: ".claude/agents/review-quality-structural.md"
  
  reviewer_docs:
    capabilities: ["review_documentation", "review_consistency"]
    model: "claude-haiku-4"           # Faster model sufficient for docs
    max_concurrent: 1
    prompt_template: ".claude/agents/review-docs-consistency.md"
  
  triager:
    capabilities: ["finding_triage", "auto_fixing", "confidence_scoring"]
    model: "claude-sonnet-4"
    max_concurrent: 1
    prompt_template: ".claude/agents/triager.md"
```

**Fields (per agent):**
- `capabilities`: List of tasks this agent can handle (used for routing)
- `model`: LLM model identifier (e.g., "claude-sonnet-4", "gpt-4", "claude-opus-4")
- `max_concurrent`: Parallelism limit for this agent type
- `prompt_template`: Path to agent-specific prompt (relative to project root)
- `timeout_override_ms`: Optional per-agent timeout override

**Agent Selection:**
Supervisor selects agents based on:
1. Phase requirements (e.g., testing phase → tester agent)
2. Capability matching (e.g., review_specification → reviewer_spec)
3. Availability (respects max_concurrent limits)
4. Model cost/performance trade-offs

**Communication Protocol:**
- Supervisor constructs prompts using templates + context
- Subagent receives: phase contract, input artifacts, constraints
- Subagent returns: status, output artifacts, metadata
- Supervisor validates outputs against schemas

---

### 9. Extensions (`extensions`)

Optional hooks for advanced features.

```yaml
extensions:
  observability:                          # REDACTED telemetry (organizational standard)
    enabled: true                         # Enable REDACTED observability
    provider: "agentaware"                # agentaware | langfuse_direct | none
    spec_version: "1.1.0"                # REDACTED specification version

    # Langfuse connection (environment variables take precedence over profile values)
    langfuse:
      host: ""                            # LANGFUSE_HOST env var preferred
      public_key: ""                      # LANGFUSE_PUBLIC_KEY env var preferred
      secret_key: ""                      # LANGFUSE_SECRET_KEY env var preferred

    # Identity (REDACTED SPEC section 2.3-2.4)
    identity:
      app_id: "{{PROJECT_NAME}}"          # Service-level identifier; resolves from profile.identity.project_name
      agent_id: ""                        # Default agent_id (overridable per subagent)

    # Sensitivity classification (REDACTED SPEC section 2.6)
    sensitivity:
      default_type: "INTERNAL"            # PUBLIC | INTERNAL | CONFIDENTIAL | HIGHLY_CONFIDENTIAL
      default_labels: []                  # e.g., ["SOURCE_CODE", "PII"]

    # CDO compliance metadata (REDACTED SPEC section 2.7)
    cdo:
      enabled: false                      # Enable CDO metadata capture on retriever spans
      default_operation: "read"           # Default operation type for CDO metadata

    # Compliance enforcement
    compliance:
      mode: "warn"                        # warn | error | off (maps to AA_COMPLIANCE_MODE)

  language_specific:
    rust:
      edition: "2021"
      features: ["async", "serde"]
    # Could add Python, Go, etc. specific settings
  
  custom_validators:
    - name: "no_todo_comments"
      command: "grep -r 'TODO' src/ && exit 1 || exit 0"
      phase: "pre_merge"
  
  retry_policies:
    - phase: "test_cmd_full"
      max_retries: 2
      backoff_ms: [1000, 5000]

  ui_framework:                          # UI component library preference
    name: "mui"                          # Framework name: mui | chakra | radix | none
    context_path: ".claude/context/ui-framework"  # Path to fetched context docs
    component_import_prefix: "@mui/material"  # Import path for components
    style_import: ""                     # Global style import (if any)

  bootstrap:                            # Template bootstrapping configuration
    templates:                          # Explicit template-to-layer mapping
      - source: ".claude/context/rust-core-lib"
        layer: "core"                   # Target polyglot layer
        placeholders:                   # Override placeholder values
          PROJECT_NAME: "my-project"
      - source: ".claude/context/react-spa"
        layer: "ui"
      - source: ".claude/context/example-python-agent"
        layer: "agentic"
        placeholders:
          PACKAGE_NAME: "my_project_agent"
    auto_detect: true                   # Run inference on unlisted templates in templates_dir
    instantiation_strategy: "copy"      # copy | symlink
    post_setup_cmd: ""                  # Run after all templates instantiated

  moldable:                             # Moldable Design Canvas (see moldable-canvas.md)
    enabled: false
    inspectability_protocol: true       # Enable cross-language inspectability protocol
    example_object_paths:               # Directories where example objects are stored
      - "tests/examples/"
    runtime_value_store:
      enabled: false                   # Enable persistent runtime value store
      backend: "filesystem"            # Storage backend (filesystem | database)
      path: ".claude/artifacts/runtime-values"
    workbench:
      contextual_playground: true       # Enable Python REPL bound to selected objects
      promote_to_tool: true            # Enable "promote to tool" workflow

  hot_reload:                           # Tiered Hot-Reload Strategy (see hot-reload.md)
    enabled: false
    tiers:
      ui: "hmr"                         # Tier 0: TypeScript HMR (hmr | full_reload)
      agentic: "process_restart"        # Tier 1: Python restart with state restore
      core: "out_of_process"            # Tier 2: Rust reload strategy (out_of_process | dylib | wasm)
    snapshot_cmd: "{{component}}_snapshot"   # Command template for state snapshot
    restore_cmd: "{{component}}_restore"      # Command template for state restore
    quiescence_timeout_ms: 5000         # Max wait for in-flight requests to drain
    migration_function_path: "migrations/"   # Directory containing migration functions

  component_model:                      # Full-Stack Component Model (see component-model.md)
    enabled: false
    interface_versioning: true          # Require interface_hash + semver on exported APIs
    interface_hash_algorithm: "sha256"  # Hash algorithm for interface versioning
    conformance_test_generation: true   # Auto-generate round-trip conformance tests
    evidence_artifact_dir: ".claude/artifacts/evidence"   # Directory for evidence artifacts
```

**Fields:**
- `observability`: REDACTED telemetry configuration. See [observability-standard.md](./observability-standard.md) for the full instrumentation specification
  - `enabled`: Master toggle for observability integration
  - `provider`: Telemetry provider — `"agentaware"` (recommended), `"langfuse_direct"` (Langfuse without REDACTED extensions), or `"none"`
  - `spec_version`: REDACTED specification version for compatibility tracking
  - `langfuse`: Langfuse connection parameters. Environment variables (`LANGFUSE_HOST`, `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`) take precedence over these values
  - `identity.app_id`: Service-level identifier per REDACTED spec section 2.3. Resolves from `{{PROJECT_NAME}}` by default. Overridable via `AGENTAWARE_APP_ID` env var
  - `identity.agent_id`: Default agent identifier per REDACTED spec section 2.4. Subagents override this with their own `agent_id`
  - `sensitivity.default_type`: Default sensitivity classification tier (REDACTED spec section 2.6). Controls what data is replicated to REDACTED Central
  - `sensitivity.default_labels`: Default sensitivity labels from the controlled vocabulary: `PII`, `FINANCIAL`, `REGULATORY`, `CLIENT`, `STAFF`, `SOURCE_CODE`, `CREDENTIAL`, `HEALTH`, `MODEL_PROMPT`, `MODEL_OUTPUT`, `GEOLOCATION`, `OTHER`
  - `cdo.enabled`: Enable CDO (Chief Data Officer) consent metadata capture on retriever spans per REDACTED spec section 2.7
  - `cdo.default_operation`: Default operation type (`"read"` or `"write"`) for CDO metadata
  - `compliance.mode`: Enforcement level — `"warn"` (log warnings), `"error"` (raise exceptions), `"off"` (silent). Maps to `AA_COMPLIANCE_MODE` environment variable
- `language_specific`: Arbitrary per-language config
- `custom_validators`: Project-specific checks
- `retry_policies`: Transient failure handling
- `ui_framework`: UI component library preference for the `typescript-ui` agent. When configured, the agent prefers the specified library's components over raw HTML elements
  - `name`: Framework identifier — `"mui"`, `"chakra"`, `"radix"`, or `"none"` (use raw primitives)
  - `context_path`: Path to fetched context documentation (e.g., `.claude/context/ui-framework`)
  - `component_import_prefix`: Import path prefix for the library's components (e.g., `@mui/material`)
  - `style_import`: Global CSS import for the library's styles
- `bootstrap`: Template bootstrapping configuration. Controls how templates in `layout.templates_dir` are discovered, composed, and instantiated into `layout.code_dir`. See [template-bootstrap.md](./template-bootstrap.md) for full specification
  - `templates[]`: Explicit list of template-to-layer mappings with placeholder overrides
  - `auto_detect`: If `true`, also scan `templates_dir` for templates not explicitly listed (inference fills gaps)
  - `instantiation_strategy`: How files are placed in `code_dir` — `"copy"` (default, full copy) or `"symlink"` (development convenience, not recommended for production)
  - `post_setup_cmd`: Optional command to run after all templates are instantiated and their individual setup commands complete
- `moldable`: Moldable Design Canvas configuration. See [moldable-canvas.md](./moldable-canvas.md) for the full specification
  - `enabled`: Master toggle for moldable features. When false, agents skip all moldable-specific patterns
  - `inspectability_protocol`: When true, specialist agents implement the inspectability protocol (describe, views, actions, search_providers, render, run) for components
  - `example_object_paths`: Directories containing example.v1 artifacts produced by EDD tests
  - `runtime_value_store.enabled`: Enable the content-addressed store for runtime values
  - `runtime_value_store.backend`: Storage backend. `"filesystem"` for v0, `"database"` for future graph DB
  - `runtime_value_store.path`: Path for filesystem-backed store, relative to project root
  - `workbench.contextual_playground`: Enable the Python REPL contextual playground pane
  - `workbench.promote_to_tool`: Enable the "promote to tool" workflow for capturing analysis scripts
- `hot_reload`: Tiered Hot-Reload Strategy configuration. See [hot-reload.md](./hot-reload.md) for the full specification
  - `enabled`: Master toggle. When false, no hot-reload orchestration is applied
  - `tiers.ui`: TypeScript reload strategy. `"hmr"` for Vite/webpack HMR, `"full_reload"` for full page reload
  - `tiers.agentic`: Python reload strategy. `"process_restart"` restarts the worker with state restore
  - `tiers.core`: Rust reload strategy. `"out_of_process"` (recommended v0), `"dylib"` (dev-only), `"wasm"` (portable)
  - `snapshot_cmd` / `restore_cmd`: Command templates for state operations. `{{component}}` is replaced with the component name
  - `quiescence_timeout_ms`: Maximum time (ms) to wait for in-flight requests to drain before snapshot
  - `migration_function_path`: Directory containing migration functions for schema changes
- `component_model`: Full-Stack Component Model configuration. See [component-model.md](./component-model.md) for the full specification
  - `enabled`: Master toggle. When false, component model patterns are not enforced
  - `interface_versioning`: Require interface_hash and semver on all exported APIs
  - `interface_hash_algorithm`: Algorithm for computing interface hashes (default: sha256)
  - `conformance_test_generation`: Auto-generate round-trip tests per exported function
  - `evidence_artifact_dir`: Directory for storing evidence artifacts (test outputs, traces, proofs)

---

## III. Token Resolution

Agents and commands reference tokens using `{{TOKEN_NAME}}` syntax. The profile resolver expands these at runtime:

```
{{LANGUAGE}}              → profile.identity.language
{{PROJECT_ROOT}}          → profile.identity.project_root
{{CODE_DIR}}              → profile.layout.code_dir
{{TEMPLATES_DIR}}         → profile.layout.templates_dir
{{SRC_PATHS}}             → profile.layout.src_paths (array)
{{TEST_CMD_FULL}}         → profile.toolchain.test_cmd_full
{{SKIP_POLICY}}           → profile.governance.skip_policy
{{REVIEW_AGENTS}}         → profile.review_graph.agents (array)
{{STATUS_TODO}}           → profile.lifecycle.states[name="todo"]
```

Nested structures use dot-notation or array indexing as needed.

---

## IV. Validation Rules

Before using a profile, the system MUST validate:

1. **Schema Conformance**: All required fields present and typed correctly
2. **Path Existence**: `project_root` exists; `*_dir` paths are writable
3. **Command Executability**: All `toolchain.*_cmd` resolve to executable programs
4. **FSM Soundness**: Lifecycle states form a valid DAG; all states reachable
5. **Agent References**: `review_graph.agents[].prompt_template` files exist
6. **Batch Consistency**: Agent batch IDs match defined batch list

---

## V. Example Profiles

### Rust Library

```yaml
identity:
  project_name: "oxide-vm"
  language: "Rust"
  runtime: "native"
  project_root: "/Users/damien/code/oxide-vm"

layout:
  src_paths: ["src/"]
  test_paths: ["tests/", "src/**/test_*.rs"]
  doc_paths: ["README.md", "docs/", "src/**/*.rs"]
  task_todo_dir: ".claude/features/todo"
  task_completed_dir: ".claude/features/completed"
  tracker_file: ".claude/features/ticket_tracker.md"
  artifact_output_dir: ".workflow-artifacts"

toolchain:
  package_install_cmd: "cargo fetch"
  precheck_cmd: "cargo check --all"
  test_cmd_full: "cargo test --all -- --nocapture --test-threads=1"
  test_cmd_targeted: "cargo test {target} -- --nocapture"
  test_output_format: "cargo_json"
  format_cmd: "cargo fmt --all --check"
  lint_cmd: "cargo clippy --all -- -D warnings"

governance:
  skip_policy: "warn"
  xfail_policy: "allow"
  autofix_confidence_rules:
    - {condition: "confidence >= 0.9", action: "apply_automatically"}
    - {condition: "default", action: "suggest_only"}
  max_fix_iterations: 3

review_graph:
  enabled: true
  agents:
    - {id: "correctness_spec", prompt_template: ".claude/agents/review-correctness-specification.md", model: "claude-sonnet-4", batch: 1}
    - {id: "quality_structural", prompt_template: ".claude/agents/review-quality-structural.md", model: "claude-sonnet-4", batch: 2}
  batches:
    - {id: 1, parallel: true, blocking: true}
    - {id: 2, parallel: true, blocking: false}

lifecycle:
  states:
    - {name: "todo", initial: true}
    - {name: "refined"}
    - {name: "done", terminal: true}
  required_fields: ["title", "description"]
```

### Python SDK

```yaml
identity:
  project_name: "langfuse-python"
  language: "Python"
  runtime: "interpreted"
  project_root: "/Users/damien/code/langfuse-python-sdk"

layout:
  src_paths: ["langfuse/"]
  test_paths: ["tests/"]
  doc_paths: ["README.md", "docs/"]
  task_todo_dir: ".claude/features/todo"
  task_completed_dir: ".claude/features/completed"
  tracker_file: ".claude/features/ticket_tracker.md"
  artifact_output_dir: "artifacts"

toolchain:
  package_install_cmd: "uv sync --all-extras --dev"
  precheck_cmd: "uv run ruff check ."
  test_cmd_full: "uv run pytest tests/ -v"
  test_cmd_targeted: "uv run pytest {target} -v"
  test_output_format: "pytest_json"
  format_cmd: "uv run ruff format ."
  lint_cmd: "uv run ruff check . && uv run mypy langfuse/"

governance:
  skip_policy: "fail"
  xfail_policy: "fail"
  autofix_confidence_rules:
    - {condition: "confidence >= 0.85 AND risk == 'low'", action: "apply_automatically"}
  max_fix_iterations: 5

review_graph:
  enabled: true
  agents:
    - {id: "correctness_spec", prompt_template: ".claude/agents/review-correctness-specification.md", model: "claude-sonnet-4", batch: 1}
    - {id: "correctness_defensive", prompt_template: ".claude/agents/review-correctness-defensive.md", model: "claude-sonnet-4", batch: 1}
    - {id: "quality_structural", prompt_template: ".claude/agents/review-quality-structural.md", model: "claude-sonnet-4", batch: 2}
    - {id: "quality_structural_codex", prompt_template: ".claude/agents/review-quality-structural.md", model: "gpt-4", batch: 2}
    - {id: "quality_evolutionary", prompt_template: ".claude/agents/review-quality-evolutionary.md", model: "claude-sonnet-4", batch: 2}
    - {id: "quality_evolutionary_codex", prompt_template: ".claude/agents/review-quality-evolutionary.md", model: "gpt-4", batch: 2}
    - {id: "docs_consistency", prompt_template: ".claude/agents/review-docs-consistency.md", model: "claude-sonnet-4", batch: 2}
  batches:
    - {id: 1, parallel: true, blocking: true}
    - {id: 2, parallel: true, blocking: false}

lifecycle:
  states:
    - {name: "todo", initial: true}
    - {name: "refined"}
    - {name: "in_progress"}
    - {name: "done", terminal: true}
    - {name: "blocked", requires_user: true}
  required_fields: ["title", "description", "acceptance_criteria", "definition_of_done"]
```

---

## VI. Usage in Workflow Steps

Each phase reads the profile and resolves tokens before execution:

```python
# Conceptual pseudocode
def run_test_phase(profile: ProjectProfile, ticket_id: str):
    # Resolve tokens
    test_cmd = profile.toolchain.test_cmd_full
    test_paths = profile.layout.test_paths
    skip_policy = profile.governance.skip_policy
    
    # Execute with profile-specific behavior
    result = execute_command(test_cmd, cwd=profile.identity.project_root)
    failures = parse_test_output(result.stdout, format=profile.toolchain.test_output_format)
    
    # Apply policy
    if skip_policy == "fail" and any(f.status == "skipped" for f in failures):
        return PhaseResult(status="failure", error={"code": "SKIPPED_TESTS_NOT_ALLOWED"})
    
    return PhaseResult(status="success", artifacts=[...])
```

---

## VII. Benefits of This Approach

1. **Single Source of Truth**: All project-specific knowledge in one file
2. **Language Agnostic**: Same workflow logic works for Rust, Python, Go, Java, etc.
3. **Testable**: Can validate profiles independently before running workflows
4. **Versionable**: Profiles live in repo; changes are tracked and reviewable
5. **Composable**: Can inherit/merge profiles (e.g., base + environment-specific overrides)

---

This schema completes the parameterization layer, making workflows truly generic across any $L$.
