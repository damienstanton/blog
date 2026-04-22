# Full-Stack Component Model: Contracts and Evidence

This specification defines the **Full-Stack Component Model** — a component as a bundle of contracts and evidence, not just code. A component comprises six parts: Core (Rust), Interface Contract, Agent Hooks (Python), UX Bindings (TypeScript), Examples, and Evidence Artifacts. This model extends the harness-kit's existing [polyglot-architecture](./polyglot-architecture.md) `component_layers` concept by making contracts explicit, versioned, and evidence-backed, as defined in the [moldable design canvas architecture](./moldable-canvas.md).

---

## I. Overview

A **component** in the harness-kit sense is a **bundle of contracts and evidence**, not merely implementation code. This extends the existing polyglot `component_layers` (core, ffi, ui, agentic, embedded) defined in [polyglot-architecture.md](./polyglot-architecture.md) by:

1. **Contract-first design:** The interface is an IDL-ish schema with versioning and conformance tests
2. **Evidence as first-class:** Test outputs, traces, snapshots, and review findings are stored alongside the component
3. **Moldability:** Components expose inspectable live objects via the [moldable-canvas](./moldable-canvas.md) protocol

The six-part component bundle is:

| Part | Language | Purpose |
|------|-----------|---------|
| **Core** | Rust | Algorithms, data structures, single source of truth |
| **Interface Contract** | Rust + Diplomat macros | FFI bindings, docs, conformance tests, interface hash |
| **Agent Hooks** | Python | Tool interfaces for querying, transforming, testing |
| **UX Bindings + Views** | TypeScript | UI contracts, renderers for inspectable objects |
| **Examples** | Rust/Python/TypeScript | Tests that return explorable objects |
| **Evidence Artifacts** | Normalized artifacts | Test outputs, traces, snapshots, review findings |

A component manifest (see §VIII) ties these parts together with provenance and version metadata.

---

## II. Core (Rust Crate)

The **Core** is the Rust crate implementing the component's business logic. It is the single source of truth consumed by all other layers via the Interface Contract.

### FFI-Oriented API Surface

The Core's public API must be designed for FFI consumption. Following [polyglot-architecture.md](./polyglot-architecture.md) layer definitions:

- **No borrowed references across boundary:** Types exposed to FFI must not rely on Rust borrows; use owned data, `Box<T>`, or explicit `(ptr, len)` with clear ownership rules
- **No generic exports:** Generics cannot cross FFI; use concrete types or monomorphized wrappers
- **Explicit ownership:** Every exported function must document who owns returned values (caller frees vs. component retains)

### Deterministic Serialization

State and data exchanged with other layers must use deterministic serialization formats:

- **JSON:** For human-readable state, config, and artifact payloads
- **Binary snapshots:** For high-fidelity state capture (e.g., `bincode` or `postcard` with fixed schema version)
- **Schema versioning:** Every serialized structure includes `schema_version` for migration

### Property Tests Emitting Artifacts

Core logic is property-tested with [proptest](https://docs.rs/proptest). Tests may emit **example artifacts** (JSON + binary) rather than only pass/fail. These become explorable examples in the workbench. See [rust-core](../agents/rust-core.md) agent for patterns.

**Reference:** [polyglot-architecture.md](./polyglot-architecture.md) §IV (Rust Core Agent), [moldable-canvas.md](./moldable-canvas.md) §IV (Example Object pattern)

---

## III. Interface Contract

The **Interface Contract** is an IDL-ish schema that defines the component boundary. Implemented via Rust + [Diplomat](https://github.com/rust-diplomat/diplomat) macros, it generates FFI bindings, documentation, and conformance tests.

### Schema and Bindings Generation

- **Source:** `#[diplomat::bridge]` modules in the FFI layer
- **Outputs:** C/C++/TypeScript/Python bindings, generated docs, round-trip conformance tests
- **Validation:** `cargo diplomat-verify` ensures FFI soundness

### Versioning

- **Interface hash:** SHA-256 of the public API surface (exported function signatures, types). Any change to the surface yields a new hash
- **Semver:** Semantic versioning for backward compatibility. Hot reload occurs only when the new interface is backward-compatible or a migration path exists

### Conformance Tests

Auto-generated **round-trip tests** per exported function:

- Each exported function gets a conformance test that exercises the FFI boundary
- Tests verify type marshalling, error propagation, and ownership semantics
- Stored as part of the component bundle

**Reference:** [diplomat-ffi](../agents/diplomat-ffi.md), [workflow-contract.md](./workflow-contract.md) §II.5 (FFI invariants), [polyglot-architecture.md](./polyglot-architecture.md) §IV

---

## IV. Agent Hooks (Python)

**Agent Hooks** are tool interfaces — "effects" — for querying, transforming, and testing components. They enable the Python agentic layer to interact with the Rust core via FFI in a consistent, typed manner.

### Algebraic Effects Alignment

Agent hooks align with **algebraic effects for orchestration** ([basis.md](./basis.md) §VII). The agent requests effects (query, transform, test); handlers interpret them. Computations are explicit, not ambient.

### Tool Protocol

Each hook is a well-defined tool with:

- **Input schema:** JSON Schema for parameters
- **Output schema:** Typed result or structured error
- **Logging:** Every call is logged for observability ([observability-standard.md](./observability-standard.md))

### Example: Querying Component State

```python
# Agent tool that inspects Rust core state via FFI
from my_app_core import RateLimiter

@observe(as_type="tool")
def inspect_rate_limiter(handle_id: str) -> dict:
    """Query a RateLimiter's internal state for inspection."""
    limiter = get_handle(handle_id)  # Resolve opaque handle
    return limiter.snapshot_json()   # Serialize to JSON via FFI
```

**Reference:** [python-agentic](../agents/python-agentic.md), [basis.md](./basis.md)

---

## V. UX Bindings + Views (TypeScript)

**UX Bindings** provide UI contracts and renderers for inspectable objects. They implement the **inspectability protocol** from [moldable-canvas.md](./moldable-canvas.md) §III.

### Inspectability Protocol

Any runtime object participating in the moldable experience implements:

- `describe(object_ref) → DescribeResult`
- `views(object_ref) → ViewDescriptor[]`
- `actions(object_ref) → ActionDescriptor[]`
- `render(view_id, object_ref, params) → RenderModel`
- `run(action_id, object_ref, params) → Result<ActionResult, Error>`

### React Components for ViewDescriptors

TypeScript UI implements React components that render `RenderModel`:

- **ViewDescriptor** defines available views (tree, table, graph, text, custom)
- **RenderModel** supplies the data payload and metadata
- Components are pure; all domain logic comes from the core via bindings

```typescript
// Example: Component that renders a ViewDescriptor's output
interface MoldableViewProps {
  viewId: string;
  objectRef: string;
  renderModel: RenderModel;
}

export function MoldableView({ viewId, objectRef, renderModel }: MoldableViewProps) {
  switch (renderModel.format) {
    case "tree":
      return <TreeRenderer data={renderModel.data} />;
    case "table":
      return <TableRenderer data={renderModel.data} />;
    default:
      return <TextRenderer data={renderModel.data} />;
  }
}
```

**Reference:** [typescript-ui](../agents/typescript-ui.md), [moldable-canvas.md](./moldable-canvas.md) §III

---

## VI. Examples

**Examples** are tests that return objects — Example-Driven Development (EDD) per [moldable-canvas.md](./moldable-canvas.md) §IV (Example Object pattern). Green tests become reusable, explorable starting points for the workbench.

### Per-Language Patterns

| Language | Pattern | Artifact Output |
|----------|---------|-----------------|
| **Rust** | Proptests emitting JSON + binary snapshots | `example.v1` schema; stored in artifact store |
| **Python** | Pytest fixtures as example object producers | Fixtures return domain objects; serialized for workbench |
| **TypeScript** | Storybook stories as explorable examples | Stories execute and produce inspectable outputs |

### Rust: Proptests Emitting Artifacts

```rust
// Proptest that emits an example artifact
proptest! {
    #[test]
    fn rate_limiter_example(max in 10u32..100, requests in 50usize..200) {
        let mut limiter = RateLimiter::new(max, 60);
        let results: Vec<bool> = (0..requests).map(|_| limiter.check("client1")).collect();
        let example = ExampleArtifact { max, requests, results };
        emit_example_artifact(&example);  // Writes to artifact store
        prop_assert!(results.iter().filter(|&&r| r).count() <= max as usize);
    }
}
```

### Python: Fixtures as Example Producers

```python
@pytest.fixture
def rate_limiter_example() -> RateLimiter:
    """Fixture that produces an explorable RateLimiter instance."""
    limiter = RateLimiter(max_requests=60, window_secs=60)
    for _ in range(30):
        limiter.check("client_a")
    return limiter  # Output, not just input
```

### TypeScript: Storybook as Examples

Storybook stories that execute and return `RenderModel` become explorable in the workbench. Each story is an Example Object.

### Connection to Test Adapter

EDD aligns with [test-adapter.md](./test-adapter.md): tests may produce structured outputs in addition to pass/fail. The `example.v1` schema (see [artifact-contracts.md](./artifact-contracts.md)) standardizes example artifacts. The EDD section in [test-adapter.md](./test-adapter.md) §X formalizes this.

**Reference:** [test-adapter.md](./test-adapter.md), [artifact-contracts.md](./artifact-contracts.md), [moldable-canvas.md](./moldable-canvas.md) §IV

---

## VII. Evidence Artifacts

**Evidence artifacts** are the constructive output of the component lifecycle: test outputs, traces, snapshots, proofs (optional), and review findings. All stored in the harness-kit's normalized artifact format.

### Artifact Types

| Type | Source | Schema |
|------|--------|--------|
| Test outputs | Phase 4 (Testing) | `test_run.v1` |
| Traces | REDACTED telemetry | W3C Trace Context |
| Snapshots | State capture, hot reload | Component-specific |
| Proofs | Aeneas/Lean (optional) | Verification artifact |
| Review findings | Phase 5 (Review) | `finding.v1` |

### Provenance Linking

Every evidence artifact carries provenance:

- **ticket_id:** Which ticket produced this artifact
- **trace_id:** Which workflow trace (REDACTED)
- **code_version:** Git commit or build identifier
- **generation_id:** For hot reload; links to component generation

### Observability as Evidence

REDACTED traces ([observability-standard.md](./observability-standard.md)) are evidence: workflow executions, phase spans, tool calls, and FFI invocations. Traces propagate W3C Trace Context and are queryable in the workbench.

### Storage

Artifacts are stored per [artifact-contracts.md](./artifact-contracts.md): dual output (JSON + Markdown), normalized per [normalization-rules.md](./normalization-rules.md), and archived per workflow phase.

**Reference:** [artifact-contracts.md](./artifact-contracts.md), [observability-standard.md](./observability-standard.md)

---

## VIII. Component Manifest Schema

The **component manifest** is a JSON document that ties the six parts together. It lives at the root of the component bundle (e.g., `component.json`).

### Schema

```json
{
  "schema_version": "component.v1",
  "component_name": "rate-limiter",
  "version": "1.2.0",
  "layers": {
    "core": {
      "path": "core/",
      "artifacts": ["*.rs", "Cargo.toml"]
    },
    "interface": {
      "path": "core/src/ffi/",
      "interface_hash": "a3f2b8c1d4e5f6a7",
      "conformance_tests": ["core/tests/ffi_conformance.rs"]
    },
    "hooks": {
      "path": "agents/tools/",
      "artifacts": ["rate_limiter_tools.py"]
    },
    "ux": {
      "path": "ui/components/",
      "artifacts": ["RateLimitStatus.tsx", "RateLimitView.tsx"]
    },
    "examples": {
      "rust": ["core/tests/proptest_*.rs"],
      "python": ["agents/tests/test_rate_limiter_fixtures.py"],
      "typescript": ["ui/src/stories/RateLimit.stories.tsx"]
    },
    "evidence": {
      "artifact_dir": ".claude/artifacts",
      "provenance_fields": ["ticket_id", "trace_id", "code_version", "generation_id"]
    }
  },
  "interface_hash": "a3f2b8c1d4e5f6a7",
  "state_schema_version": "1.0",
  "dependencies": [
    {"name": "serde", "version": "1.0"}
  ],
  "provenance": {
    "ticket_id": "TASK-063",
    "trace_id": "00-abc123-def456-01",
    "code_version": "a1b2c3d4",
    "generation_id": "gen_001"
  }
}
```

### Field Descriptions

| Field | Purpose |
|-------|---------|
| `component_name` | Human-readable identifier |
| `version` | Semver for the component |
| `layers` | Paths and artifacts for each of the six parts |
| `interface_hash` | SHA-256 (first 8 hex) of public API surface |
| `state_schema_version` | Version of serialized state format |
| `dependencies` | External crate/package dependencies |
| `provenance` | Ticket, trace, code version, generation for audit |

### ID Generation

Component and layer IDs follow [normalization-rules.md](./normalization-rules.md) §VI: content-hash based, deterministic.

---

## Related Specifications

| Spec | Relationship |
|------|--------------|
| [polyglot-architecture.md](./polyglot-architecture.md) | Defines `component_layers`; this spec extends with contracts and evidence |
| [moldable-canvas.md](./moldable-canvas.md) | Inspectability protocol (§III) implemented by UX Bindings |
| [artifact-contracts.md](./artifact-contracts.md) | Evidence artifact formats, dual output, lineage |
| [observability-standard.md](./observability-standard.md) | Traces as evidence; REDACTED integration |
| [test-adapter.md](./test-adapter.md) | EDD; tests that return example objects |
| [normalization-rules.md](./normalization-rules.md) | ID generation, deterministic artifact format |
| [basis.md](./basis.md) | Algebraic effects for Agent Hooks |
