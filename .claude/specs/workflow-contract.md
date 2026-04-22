# Workflow Contract: Foundation for Language-Agnostic Automation

This specification defines the universal invariants that govern all workflow steps for any language/project $L$. It is grounded in the Computational Type Theory framework from [basis.md](./basis.md), translating its formal structure into executable workflow contracts.

---

## I. Foundation Mapping: CTT → Workflow

The CTT system ([basis.md](./basis.md)) provides a blueprint for deterministic, verifiable processes. Each section of the formal basis maps to a concrete workflow invariant:

| CTT Concept (basis.md §) | Workflow Analog | Purpose |
|---------------------------|-----------------|---------|
| **Domain / Abstract Syntax** (§I) | `input_contract` | Defines valid workflow inputs as inductive ADTs with clear schema — mirroring how CTT defines the universe of expressions $\text{Expr}$ |
| **Dynamics / Operational Semantics** (§II) | `transition_rules` | Specifies deterministic state transitions between workflow phases — mirroring how CTT defines the transition system $E \mapsto E'$ |
| **Verifier / Judgemental Equality** (§III) | `validation_rules` | Establishes equivalence/correctness checks at each gate — mirroring how CTT verifies $M \doteq M' \in A$ by evaluating to canonical forms |
| **Functionality** (§IV) | `compositional_determinism` | Phases respect equality of inputs: if two runs receive equal inputs, they produce equal outputs — mirroring CTT's Fundamental Lemma that families respect equality of indices |
| **Propositions as Types** (§V) | `specification_as_schema` | Artifact schemas *are* specifications; a conforming artifact *is* a proof that the phase succeeded — mirroring Curry-Howard where types are propositions and inhabitants are proofs |
| **Totality** (§VIII) | `bounded_execution` | Every phase terminates in bounded steps via max iterations or gas limits — mirroring CTT's total evaluator requirement |
| **Error as Data** (§VIII) | `error_as_data` | Failures are explicit sum-type variants (`Result<T, E>`), not exceptions — mirroring CTT's treatment of stuck terms as data, never crashes |
| **Algebraic Effects** (§VII) | `effect_handling` | Side effects (tool calls, I/O, test execution) are structured operations with parameter types and continuations — mirroring Bauer's algebraic effect signatures $Op : B \times A^C \to A$ |
| **Design Consequences** (§IX) | `value_semantics` | All workflow data uses value semantics, sum types for variants, product types for composition — mutative inheritance and mixins are structurally incompatible with CTT's judgemental equality and functionality |
| **Agentic Stack** (§X) | `language_triad` | Rust (canonical core) + Python (agentic effects) + TypeScript (structural verification) — the CTT-optimal language combination for agent systems, with state-of-the-art patterns for each |

---

## II. Universal Invariants

All workflow steps in any project $L$ MUST satisfy:

### 1. Input Contract (`input_contract`)

Every workflow phase declares its valid inputs as inductive data types, mirroring how CTT's Domain ([basis.md](./basis.md) §I) defines the universe of expressions. Just as $\text{Expr}$ is defined inductively ($e ::= x \mid \lambda x.e \mid \text{ap}(e_1, e_2) \mid \ldots$), each phase declares its input grammar:

- **Schema**: ADT-style definition of valid inputs (required fields, types, constraints) — the inductive set of valid expressions
- **Provenance**: Source of each input (user, prior phase, project profile)
- **Validation**: Predicate that accepts/rejects inputs before execution begins — membership check ($M \in A$)

**Example Template:**
```yaml
phase: implement_todos
input_contract:
  schema:
    ticket_id: {type: string, pattern: "^[A-Z]+-\\d+$"}
    project_profile: {type: object, schema_ref: "profile.v1"}
    change_scope: {type: enum, values: [minimal, moderate, extensive]}
  provenance:
    ticket_id: user_selection
    project_profile: resolved_context
    change_scope: inferred_by_agent
  validation:
    - ticket_id exists in {{TASK_TODO_DIR}}
    - project_profile.language is supported
    - all profile.toolchain commands are executable
```

### 2. Transition Rules (`transition_rules`)

Each phase executes as a **deterministic finite state machine**, mirroring CTT's operational semantics ([basis.md](./basis.md) §II) where $E \mapsto E'$ defines a single computation step and $E \Downarrow E_\circ$ defines evaluation to a canonical form:

- **States**: Explicit enumeration (e.g., `idle`, `running`, `validating`, `success`, `failure`, `blocked`) — corresponding to expression forms in the dynamics
- **Transitions**: Total function mapping `(current_state, event) → next_state` — corresponding to the deterministic transition relation $\mapsto$
- **Termination**: Every path reaches a final state in bounded steps (enforced by max iterations or gas limit) — corresponding to CTT's total evaluator requirement with a "gas" budget

**Example Template:**
```yaml
phase: test_and_fix
transition_rules:
  initial_state: idle
  states:
    idle: {final: false}
    running_tests: {final: false, timeout_ms: 300000}
    analyzing_failures: {final: false}
    applying_fixes: {final: false}
    re_running_tests: {final: false}
    success: {final: true, exit_code: 0}
    failure: {final: true, exit_code: 1}
    blocked: {final: true, exit_code: 2, requires_user: true}
  transitions:
    - {from: idle, event: start, to: running_tests}
    - {from: running_tests, event: all_pass, to: success}
    - {from: running_tests, event: failures_detected, to: analyzing_failures}
    - {from: analyzing_failures, event: fixable, to: applying_fixes}
    - {from: analyzing_failures, event: unfixable, to: blocked}
    - {from: applying_fixes, event: fixes_applied, to: re_running_tests}
    - {from: re_running_tests, event: all_pass, to: success}
    - {from: re_running_tests, event: still_failing, to: blocked}
  max_iterations: 3
```

### 3. Validation Rules (`validation_rules`)

Verification at each gate mirrors CTT's judgemental equality ([basis.md](./basis.md) §III): to verify $M \doteq M' \in A$, we evaluate both to canonical forms and compare structurally based on the type. In workflow terms: to verify a phase output, we evaluate it against the expected schema and compare structurally.

- **Type**: What is being validated (artifact schema, behavioral contract, regression invariant) — the $A$ in $M \doteq M' \in A$
- **Method**: How verification occurs (structural check, test execution, semantic equivalence) — the type-indexed equality algorithm that switches on the structure of $A_\circ$
- **Threshold**: Pass/fail criteria with explicit strictness levels

**Example Template:**
```yaml
phase: review_orchestration
validation_rules:
  - type: artifact_schema
    method: json_schema_validation
    schema_ref: "finding.v1.json"
    threshold: strict
    on_failure: block_merge
  
  - type: behavioral_contract
    method: no_new_test_failures
    baseline: pre_change_snapshot
    threshold: strict
    on_failure: require_user_approval
  
  - type: regression_invariant
    method: coverage_delta
    threshold: warn_if_decrease_gt_5pct
    on_failure: log_warning
```

### 4. Error as Data (`error_as_data`)

Failures are **not exceptions**; they are explicit data variants enabling total functions. This mirrors the CTT principle from [basis.md](./basis.md) §VIII: stuck terms (e.g., applying a non-function) are data variants (`Result::Err(Stuck)`), never runtime crashes. In the propositions-as-types correspondence (§V), the sum type `PhaseResult<T>` is a logical disjunction — success *or* failure *or* blocked — and every path is covered.

- **No Runtime Crashes**: All error paths return structured results
- **Discriminated Unions**: Success and failure cases are sum types (cf. §V: $(\Phi_1 \lor \Phi_2)^\star \implies \Phi_1^\star + \Phi_2^\star$)
- **Propagation**: Errors bubble up with full context, never silently swallowed

**Example Template:**
```typescript
// Conceptual ADT (language-agnostic)
type PhaseResult<T> =
  | {status: "success", value: T, artifacts: Artifact[]}
  | {status: "failure", error: ErrorDetail, partial_artifacts: Artifact[]}
  | {status: "blocked", reason: BlockReason, requires_user: true}

type ErrorDetail = {
  code: string           // Machine-readable error code
  message: string        // Human explanation
  context: Record<string, any>  // Debugging context
  recoverable: boolean   // Can retry automatically?
}
```

### 5. FFI and Hot-Reload Invariants (`ffi_hot_reload`)

When polyglot components use FFI boundaries or hot-reload capabilities, additional invariants apply. These extend [basis.md](./basis.md) value semantics and [component-model.md](./component-model.md) interface contracts. See [hot-reload.md](./hot-reload.md) for the full reload spec and [moldable-canvas.md](./moldable-canvas.md) §I (Invariants A, D) for the moldable DX framing.

**FFI Invariants (from forge.md §7):**
1. **Opaque handles only** — Never expose Rust struct layouts across FFI. Return `HandleId` (u64) or `*mut Opaque` with explicit destructor functions.
2. **No borrowed lifetimes across boundary** — Accept owned buffers or explicit `(ptr, len)` with clear ownership rules. Strings: accept UTF-8 owned strings or use arena handle + copy-out.
3. **Result always, never panic** — All FFI calls return `Result<T, E>` style outcomes. Panics must not cross the boundary. Catch and convert to error objects.
4. **Versioned interfaces** — Every exported interface gets an `interface_hash` (SHA-256 of public API surface) and semver. Reload only occurs when backward-compatible, or a migration exists.
5. **Conformance tests at boundary** — Auto-generate round-trip tests per exported function signature. Keep as part of the component bundle.

**Hot-Reload Invariants (from forge.md §8):**
1. **Reload by generation, not mutation** — Each build is a new generation. Reload = activate N+1, not patch in place.
2. **Explicit quiescence points** — Updates only occur at well-defined safe points where no in-flight operations are active.
3. **Snapshot/restore with versioned schemas** — State is serialized with a schema version. Restore validates the version.
4. **Migration functions for schema changes** — When state schema changes between generations, a migration function transforms old state to new.
5. **Smoke examples after reload** — After restoring state, run the component's Example Objects as smoke tests before flipping traffic.

**Conceptual ADT:**
```typescript
type ReloadResult =
  | { status: "reloaded", generation_id: string, interface_hash: string }
  | { status: "blocked", reason: string, recovery_actions: string[] }

type FFICallResult<T> =
  | { status: "ok", value: T }
  | { status: "error", code: string, message: string, recoverable: boolean }
```

**Cross-references:** [hot-reload.md](./hot-reload.md) (full reload spec), [moldable-canvas.md](./moldable-canvas.md) §I (Invariants A, D), [component-model.md](./component-model.md) §III (interface contracts), [polyglot-architecture.md](./polyglot-architecture.md) (layer structure).

---

## III. Phase Composition Rules

Workflows compose phases using primitives that mirror CTT's type constructors ([basis.md](./basis.md) §I, §V): sequential composition corresponds to dependent function application ($\Pi$-types), parallel composition to product types ($\Sigma$-types), and conditional branching to the Boolean eliminator $\text{if}(E_1; E_2)(E)$.

### Sequential Composition
```
phase_A ≫ phase_B ⟺ 
  if phase_A succeeds → run phase_B with phase_A.outputs
  if phase_A fails → skip phase_B, propagate error
```

### Parallel Composition (Fan-out/Fan-in)
```
phases_parallel([A, B, C]) ⟺
  run A, B, C concurrently
  collect all results
  if any blocked → overall status = blocked
  if any failed and none blocked → overall status = failed
  if all succeeded → overall status = success
```

### Conditional Branching
```
if_then_else(predicate, phase_T, phase_F) ⟺
  evaluate predicate deterministically
  if true → run phase_T
  if false → run phase_F
```

---

## IV. Determinism Requirements

These requirements implement CTT's **equisatisfaction** property ([basis.md](./basis.md) §IV): equal indices deterministically produce equal results. In workflow terms: equal inputs to the same phase produce equal outputs.

1. **No Hidden State**: All inputs must be explicit (no ambient environment variables unless declared in profile) — mirroring CTT's requirement that a deterministic operational semantics has no ambient context
2. **Timestamp Policy**: Timestamps for audit only; never affect control flow or artifact hashing — preserving deterministic evaluation ($E \Downarrow E_\circ$ is independent of when it runs)
3. **Stable Ordering**: Lists/sets in artifacts must be canonically sorted for deterministic comparison — enabling judgemental equality ($M \doteq M' \in A$) on artifacts
4. **Idempotence**: Running the same phase twice with identical inputs produces equivalent outputs — the direct analog of CTT's Functionality: if $M \doteq M' \in A$ then $B[M/a] \doteq B[M'/a]$

---

## V. Implementation Checklist (Any Language $L$)

To implement this contract in language $L$:

1. **Define ADTs**: Create sum types for `PhaseInput`, `PhaseResult`, `ErrorDetail`, `BlockReason`
2. **Implement State Machine**: Encode transition rules as match/switch statements or state pattern
3. **Schema Validator**: Write validators that check inputs against declared contracts before execution
4. **Artifact Serialization**: Ensure JSON output respects stable ordering and versioning
5. **Logging Discipline**: Log all state transitions and validation checks for audit trail
6. **Totality Budget**: Set max iterations / timeouts to prevent infinite loops

---

## VI. Relationship to Project Profile

This contract is **universal**. The [project profile](./project-profile-schema.md) provides **parameters** that instantiate these abstractions for a specific project $L$:

- `input_contract` remains the same structure; profile fills in `{{LANGUAGE}}`, `{{TEST_CMD}}`, etc.
- `transition_rules` stay deterministic; profile configures timeouts and max iterations
- `validation_rules` keep their logic; profile specifies which validators to enable
- `error_as_data` is always enforced; profile defines custom error codes

---

## VII. Verification Strategy

Before deploying a workflow for project $L$:

1. **Schema Check**: Validate that the project profile satisfies all required fields for each phase
2. **State Machine Soundness**: Verify all states are reachable and all final states have exit codes
3. **Termination Proof**: Confirm max iterations or gas limits prevent infinite loops
4. **Error Handling Exhaustiveness**: Ensure every error case has an explicit branch
5. **Artifact Lineage**: Trace that every output artifact can be linked back to its input provenance

---

## VIII. Example: End-to-End Flow

```
[User Request]
  ↓ (input_contract: feature_description)
[Feature Intake Phase]
  ↓ (transition_rules: intake → refined)
  → validation_rules: ticket_schema_valid
  → output: ticket.json + ticket.md
  ↓ (error_as_data: success)
[Implementation Phase]
  ↓ (input_contract: ticket_id, project_profile)
  → transition_rules: plan → code → test → review
  → validation_rules: tests_pass, reviews_clean
  → output: implementation_summary.json + diff.md
  ↓ (error_as_data: success)
[Handoff Phase]
  ↓ (input_contract: session_artifacts)
  → validation_rules: all_artifacts_present, schemas_valid
  → output: consolidated_report.json + summary.md
  ↓ (error_as_data: success)
[Deterministic Pipeline] (external, outside scope)
```

---

## IX. Multi-Agent Semantics

When workflows operate in **supervisor mode** (`profile.execution.mode == "supervisor"`), the contract extends to cover delegation and coordination.

### 1. Agent Contract (`agent_contract`)

Each subagent (planner, implementer, tester, reviewer, triager) operates under a **focused contract**:

```yaml
agent: implementer
agent_contract:
  inputs:
    step: {type: Step, from: "planning_phase"}
    dependencies: {type: Artifact[], from: "prior_steps"}
    profile: {type: ProjectProfile, from: "supervisor"}
  
  capabilities:
    - code_generation
    - formatting
    - linting
  
  constraints:
    timeout_ms: 300000
    max_fix_iterations: 3
    scope: step.files_affected
  
  outputs:
    step_artifact: {schema: "iteration_step.v1", format: "json+md"}
  
  termination_guarantee:
    bounded_by: max_fix_iterations
    escape_condition: all_checks_pass OR iterations_exhausted
```

**Key Properties:**
- **Input Isolation**: Agent receives only what it needs (no global state)
- **Capability Matching**: Supervisor routes work based on declared capabilities
- **Bounded Execution**: Every agent has max runtime and iteration limits
- **Output Contract**: Agent must produce schema-validated artifacts or explicit blocked state

### 2. Delegation Rules (`delegation_rules`)

Supervisor orchestration follows deterministic rules:

```yaml
delegation_rules:
  # Phase-level delegation
  - phase: planning
    strategy: single_agent
    agent_selector: capability_match
    required_capabilities: ["planning", "decomposition"]
    parallelism: none
    blocking: true
  
  # Step-level delegation with DAG parallelism
  - phase: iteration
    strategy: per_step
    agent_selector: capability_match
    required_capabilities: ["code_generation"]
    parallelism: dag_based
    max_concurrent: profile.agents.implementer.max_concurrent
    blocking: true
  
  # Batch-level delegation with reviewer parallelism
  - phase: review
    strategy: batch
    agent_selector: batch_assignment
    batches: profile.review_graph.batches
    parallelism: batch_parallel
    max_concurrent: profile.execution.parallelism.max_parallel_agents
    blocking: configurable_per_batch
```

**Delegation Decision Function:**
```python
def select_agent(phase: Phase, capabilities: List[str], agents: Dict[str, Agent]) -> Agent:
    """Total function: always returns an agent or raises explicit error"""
    
    # 1. Filter candidates by capability
    candidates = [a for a in agents.values() if any(c in a.capabilities for c in capabilities)]
    
    if not candidates:
        return Error(code="NO_CAPABLE_AGENT", phase=phase, required=capabilities)
    
    # 2. Filter by availability (max_concurrent)
    available = [a for a in candidates if get_active_instances(a.id) < a.max_concurrent]
    
    if not available:
        return Error(code="ALL_AGENTS_BUSY", phase=phase, candidates=candidates)
    
    # 3. Select best match (deterministic tie-breaking)
    return max(available, key=lambda a: (
        len(set(a.capabilities) & set(capabilities)),  # Capability overlap
        model_rank(a.model),                            # Model quality
        -get_active_instances(a.id)                     # Least loaded
    ))
```

### 3. Coordination Invariants (`coordination_invariants`)

Multi-agent workflows maintain these properties:

```yaml
coordination_invariants:
  # Artifact handoff
  - name: artifact_continuity
    rule: "Each phase receives validated artifacts from prior phases"
    enforcement: supervisor_validates_before_delegation
  
  # Concurrency safety
  - name: bounded_parallelism
    rule: "Total active agents ≤ profile.execution.parallelism.max_parallel_agents"
    enforcement: agent_pool_manager
  
  # Dependency ordering
  - name: dag_ordering
    rule: "Step executes only after all dependencies complete successfully"
    enforcement: dag_traversal_scheduler
  
  # Progress guarantee
  - name: forward_progress
    rule: "If any agent blocks, workflow saves checkpoint and reports actionable next steps"
    enforcement: checkpoint_on_blocked_status
  
  # Determinism
  - name: reproducible_delegation
    rule: "Same inputs + same profile → same agent selection and execution order"
    enforcement: stable_sorting_with_content_hashes
```

### 4. Communication Protocol (`communication_protocol`)

Agent-to-supervisor messages follow structured format:

```typescript
// Supervisor → Agent
interface DelegationRequest {
  delegation_id: string;           // Unique ID for tracing
  agent_id: string;                // Target agent
  phase: string;                   // Current phase
  prompt: string;                  // Complete instructions
  context: {                       // Structured inputs
    ticket: Ticket;
    profile: ProjectProfile;
    artifacts: Artifact[];
    constraints: PhaseConstraints;
  };
  timeout_ms: number;
  callback_url?: string;           // Optional async mode
}

// Agent → Supervisor
interface DelegationResponse {
  delegation_id: string;
  agent_id: string;
  status: "success" | "blocked" | "failure";
  artifacts: Artifact[];           // Empty if blocked/failure
  metadata: {
    duration_ms: number;
    iterations_used?: number;
    model_used: string;
  };
  error?: {                        // Present if status != "success"
    code: string;
    message: string;
    attempted: string[];
    requires: string;
  };
}
```

**Message Invariants:**
- All fields are required (no optional top-level fields)
- `status` is explicit enum (no string literals)
- `error` is present iff `status != "success"`
- `artifacts` conform to phase output schema (validated by supervisor)

### 5. Checkpoint and Resume (`checkpoint_contract`)

When any agent blocks, supervisor saves resumable state:

```json
{
  "checkpoint_id": "TASK-001_phase-4",
  "timestamp": "2026-02-15T14:30:00Z",
  "ticket_id": "TASK-001",
  "phase": "testing",
  "completed_phases": ["preflight", "planning", "iteration"],
  "blocking_agent": "tester",
  "blocking_reason": "unfixable_test_failures",
  "user_action_required": "Review failing tests and provide fix guidance",
  "partial_artifacts": [
    {"phase": "preflight", "path": ".claude/artifacts/TASK-001_preflight.json", "valid": true},
    {"phase": "planning", "path": ".claude/artifacts/TASK-001_plan.json", "valid": true},
    {"phase": "iteration", "path": ".claude/artifacts/TASK-001_iteration.json", "valid": true},
    {"phase": "testing", "path": ".claude/artifacts/TASK-001_test_run.json", "valid": false}
  ],
  "resume_inputs": {
    "expected_type": "UserGuidance",
    "schema": {
      "skip_tests": {"type": "boolean"},
      "fix_suggestions": {"type": "array", "items": "string"},
      "policy_override": {"type": "object"}
    }
  }
}
```

**Resume Semantics:**
```python
def resume_workflow(checkpoint: Checkpoint, user_input: UserGuidance) -> PhaseResult:
    """Resume from checkpoint with user-provided corrections"""
    
    # 1. Validate checkpoint integrity
    assert all(a.valid for a in checkpoint.partial_artifacts if a.phase in checkpoint.completed_phases)
    
    # 2. Apply user input
    updated_context = apply_user_corrections(checkpoint, user_input)
    
    # 3. Resume from blocking phase (not from beginning)
    return execute_phase(
        phase=checkpoint.phase,
        context=updated_context,
        prior_artifacts=checkpoint.partial_artifacts
    )
```

### 6. Observability Contract (`observability_contract`)

Supervisor emits structured events for all delegation operations:

```json
// Phase delegation
{"event": "phase_delegated", "phase": "iteration", "agent_ids": ["implementer"], "strategy": "dag_based", "timestamp": "..."}

// Agent lifecycle
{"event": "agent_acquired", "agent_id": "implementer-1", "delegation_id": "...", "timestamp": "..."}
{"event": "agent_started", "agent_id": "implementer-1", "delegation_id": "...", "timeout_ms": 300000, "timestamp": "..."}
{"event": "agent_completed", "agent_id": "implementer-1", "status": "success", "duration_ms": 45000, "timestamp": "..."}
{"event": "agent_released", "agent_id": "implementer-1", "timestamp": "..."}

// Coordination
{"event": "step_dependencies_met", "step_id": 3, "dependencies": [1, 2], "timestamp": "..."}
{"event": "batch_started", "batch_id": 1, "agent_count": 3, "parallel": true, "timestamp": "..."}
{"event": "batch_completed", "batch_id": 1, "findings_count": 15, "duration_ms": 18000, "timestamp": "..."}

// Blocking
{"event": "workflow_blocked", "phase": "testing", "agent_id": "tester", "reason": "unfixable_failures", "checkpoint_id": "...", "timestamp": "..."}
{"event": "workflow_resumed", "checkpoint_id": "...", "user_input": {...}, "timestamp": "..."}

// Phase completion
{"event": "phase_completed", "phase": "iteration", "agents_used": 3, "total_duration_ms": 78000, "timestamp": "..."}
```

**Observability Invariants:**
- Events are append-only (no updates to prior events)
- Timestamps are monotonic within phase
- Every `agent_acquired` has matching `agent_released`
- Every `workflow_blocked` has matching `workflow_resumed` or terminal state

### 7. Verification for Multi-Agent Workflows

Additional checks for supervisor mode:

```yaml
verification_rules:
  - name: agent_registry_completeness
    check: "All agents referenced in review_graph exist in profile.agents"
    enforcement: profile_validation
  
  - name: capability_coverage
    check: "Every phase has at least one agent with required capabilities"
    enforcement: preflight_validation
  
  - name: max_concurrent_soundness
    check: "Sum of max_concurrent across all agents ≥ max_parallel_agents"
    enforcement: profile_validation
  
  - name: prompt_template_existence
    check: "All agent.prompt_template paths resolve to valid files"
    enforcement: profile_validation
  
  - name: delegation_determinism
    check: "Agent selection is deterministic given same inputs"
    enforcement: stable_sorting_in_select_agent()
  
  - name: checkpoint_recovery
    check: "Workflow can resume from any checkpoint without re-executing completed phases"
    enforcement: integration_test
```

---

## X. Extension Points

For advanced workflows:

- **User Gates**: Add `requires_user_approval` state with timeout/default behavior
- **Retry Policies**: Specify exponential backoff or fixed retry counts for transient failures
- **Partial Progress**: Allow phases to emit intermediate artifacts for long-running work
- **Observability Hooks**: Inject telemetry adapters at transition boundaries
- **Multi-Agent Coordination**: Use supervisor mode for parallel execution (see Section IX)

---

This contract ensures that workflows built for $L$ are **total**, **deterministic**, and **verifiable**, mirroring the guarantees provided by the CTT system in [basis.md](./basis.md). Multi-agent extensions preserve these properties through explicit coordination contracts and bounded delegation.
