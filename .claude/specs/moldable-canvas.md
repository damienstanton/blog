# Moldable Design Canvas: Architecture Specification

This specification defines the **Moldable Design Canvas** architecture — a live programming environment whose primary product is *decision velocity with correctness*. It treats moldable developer experience (DX) as a first-class runtime concern: storing and surfacing live examples, runtime values, traces, and proof artifacts as explorable domain objects across Rust, Python, and TypeScript, while keeping language boundaries memory-safe, versioned, and hot-reload tolerant. The design aligns with the harness-kit's existing discipline: deterministic artifacts, errors as data, polyglot layering, and the CTT foundation in [basis.md](./basis.md).

---

## I. Overview — Non-Negotiable Invariants

Four invariants anchor the Moldable Design Canvas. Each aligns with existing harness-kit principles.

### Invariant A: Component Boundary is a Versioned Contract

**Principle:** The component boundary is a versioned contract, not a pile of bindings. Rust lacks a stable ABI; any in-process hot-reload must be anchored on an ABI you control (typically C ABI) or a stable ABI framework. Without an explicit, versioned contract, hot reload degrades into "restart everything" or silent memory unsafety.

**harness-kit alignment:** The [polyglot-architecture](./polyglot-architecture.md) Diplomat pipeline already treats FFI as a contract: `#[diplomat::bridge]` defines the boundary, and `diplomat-verify` validates soundness. The Moldable Canvas extends this by requiring `interface_hash` and `semver` on every exported interface; reload occurs only when the new interface is backward-compatible or a migration path exists.

### Invariant B: Errors are Data Everywhere

**Principle:** All outcomes — workflow phases, FFI calls, tool execution, agent plans, hot reload events — are structured data. Exception-as-control-flow undermines both automation and safe reload.

**harness-kit alignment:** The [workflow-contract](./workflow-contract.md) mandates `PhaseResult<T>` and "error as data" (§II.4). The [basis.md](./basis.md) §VIII treats stuck terms as data, never crashes. The Moldable Canvas extends this to FFI (every `Result<T, E>` propagates as structured error to Python/TypeScript) and hot reload (`Reloaded(new_generation_id)` or `Blocked(reason, recovery_actions)`).

### Invariant C: Moldability Requires Live Objects + Cheap Views/Actions/Search

**Principle:** The biggest cost in development is *figuring systems out*. The lever is making it inexpensive to add custom tools that expose domain models. The platform must: (1) capture interesting live instances (examples, traces, runtime values), (2) attach custom views/actions/search to them, and (3) make those extensions cheap enough to build repeatedly.

**harness-kit alignment:** Deterministic artifacts and dual output (JSON + Markdown) in [artifact-standards](../rules/artifact-standards.md) provide a base. The Moldable Canvas adds the *inspectability protocol* (§III) — a cross-language API for describing, viewing, acting on, and searching any runtime object — so moldability is not an IDE afterthought but a platform primitive.

### Invariant D: Hot Reload is a State Migration Problem

**Principle:** Safe live updates require explicit update points and explicit state transformation between versions. The platform treats hot reload as a controlled operation with quiescence points, state snapshot/rehydration, versioned schemas, and migration functions.

**harness-kit alignment:** Phase orchestration in [workflow-phases](../rules/workflow-phases.md) uses explicit gates and bounded iteration. The Moldable Canvas applies the same discipline to reload: quiescence → snapshot → load new generation → migrate if needed → restore → smoke tests → flip traffic. This keeps hot reload from becoming "corrupt state roulette."

---

## II. Architecture — Four Subsystems

The Moldable Design Canvas comprises four cooperating subsystems:

```
Voice/UI  ──► Agent Orchestrator (Python) ──► Build/Verify/Reload Orchestrator
  ▲                     │                               │
  │                     ▼                               ▼
Moldable Workbench ◄── Artifact & Runtime Value Store ◄── Component Runtime (Rust core + bindings)
(TypeScript)             (content-addressed + queryable)      (hot-reload managed)
```

### Information Flow

1. **Voice/UI → Agent Orchestrator (Python):** User intent (voice, text, GUI) becomes workflow objects (tickets, plans, patches). The agent layer orchestrates tool calls and delegates to the build/reload orchestrator.

2. **Agent Orchestrator → Build/Verify/Reload Orchestrator:** The orchestrator runs builds, tests, FFI verification, and hot-reload cycles. It writes to the Artifact & Runtime Value Store.

3. **Component Runtime (Rust core + bindings) → Artifact & Runtime Value Store:** The Rust core (and its Diplomat-generated bindings) produces live objects, traces, examples, and state snapshots. These are stored content-addressed with metadata (ticket, trace, code version).

4. **Artifact & Runtime Value Store → Moldable Workbench (TypeScript):** The workbench queries the store, invokes the inspectability protocol on live objects, and renders custom views. It also drives the contextual playground (Python REPL bound to selected objects).

5. **Feedback loop:** The Moldable Workbench surfaces insights to the user; refinement flows back through Voice/UI and the Agent Orchestrator.

### Mapping to harness-kit Polyglot Layering

| Subsystem | harness-kit analog |
|-----------|-------------------|
| Component Runtime | [polyglot-architecture](./polyglot-architecture.md) core + FFI layers |
| Build/Verify/Reload | Phase 3 (Iteration) + Phase 4 (Testing) + hot-reload orchestration |
| Artifact & Runtime Value Store | `.claude/artifacts/` + runtime value persistence (§V) |
| Moldable Workbench | TypeScript UI layer + new workbench UI |
| Agent Orchestrator | Python agentic layer + supervisor |

---

## III. Inspectability Protocol

Any runtime object can participate in the moldable experience by implementing the **inspectability protocol**. This is a cross-language protocol: Rust core exposes it via FFI, Python agents invoke it for tooling, and the TypeScript workbench renders it.

### Core Operations

| Operation | Signature | Purpose |
|-----------|-----------|---------|
| `describe` | `describe(object_ref) → DescribeResult` | Returns type, schema version, summary, and links |
| `views` | `views(object_ref) → ViewDescriptor[]` | Lists available custom views |
| `actions` | `actions(object_ref) → ActionDescriptor[]` | Lists available domain-specific actions |
| `search_providers` | `search_providers(object_ref) → SearchDescriptor[]` | Lists search providers for the object |
| `render` | `render(view_id, object_ref, params) → RenderModel` | Produces data for the workbench to render |
| `run` | `run(action_id, object_ref, params) → Result<ActionResult, Error>` | Executes an action and returns structured result |

### TypeScript-Style Type Definitions

```typescript
/** Result of describe(object_ref) */
interface DescribeResult {
  type: string;
  schema_version: string;
  summary: string;
  links: LinkDescriptor[];
}

interface LinkDescriptor {
  rel: string;
  href: string;
  title?: string;
}

/** Descriptor for a custom view */
interface ViewDescriptor {
  id: string;
  label: string;
  category?: string;
  params_schema?: JSONSchema;  // Optional parameter schema
  description?: string;
}

/** Descriptor for a domain-specific action */
interface ActionDescriptor {
  id: string;
  label: string;
  category?: string;
  params_schema?: JSONSchema;
  description?: string;
  confirmation?: string;  // Shown before destructive actions
}

/** Descriptor for a search provider */
interface SearchDescriptor {
  id: string;
  label: string;
  placeholder?: string;
  returns: string;  // Type of matched objects
}

/** Result of render(view_id, object_ref, params) — workbench renders this */
interface RenderModel {
  view_id: string;
  format: "tree" | "table" | "graph" | "text" | "custom";
  data: unknown;  // View-specific payload
  children?: RenderModel[];  // For hierarchical views
  metadata?: Record<string, unknown>;
}

/** Result of run(action_id, object_ref, params) */
interface ActionResult {
  action_id: string;
  status: "ok" | "modified" | "blocked";
  output?: unknown;  // Action-specific result
  new_object_ref?: string;  // If action produced a new object
  message?: string;
}
```

### Cross-Language Binding

- **Rust:** Implements the protocol for core types (e.g., `PhaseResult`, traces, component state). Exposes via Diplomat FFI as opaque handles + C ABI functions.
- **Python:** Calls Rust via generated bindings; can also register Python-implemented views/actions for Python-originated objects (e.g., agent plans, tool call results).
- **TypeScript:** Consumes `DescribeResult`, `ViewDescriptor[]`, etc. from FFI; calls `render()` and displays `RenderModel`; invokes `run()` and displays `ActionResult`.

---

## IV. Moldable Patterns

Five patterns from moldable development research structure the tooling design.

### 1. Moldable Object

**Definition:** Anything you can inspect live — a component, an example result, a trace span, a phase artifact.

**When to use:** Every domain object that should be explorable in the workbench. The object implements the inspectability protocol (§III).

**harness-kit integration:** Phase artifacts (plan, iteration, test_run, review) become moldable objects. So do traces, spans, and component runtime state. The workbench can drill into any of them.

### 2. Example Object

**Definition:** A test that returns a live object; used as a stable starting point for exploration.

**When to use:** Tests (unit, integration, property) that produce representative instances. Green tests become reusable, explorable examples.

**harness-kit integration:** In Rust, tests (or proptests) emit artifacts (JSON + binary snapshot) rather than only pass/fail. In Python, pytest fixtures can be example object producers. In TypeScript, Storybook-like examples execute and become inspectable. The [artifact-contracts](./artifact-contracts.md) `example.v1` schema standardizes this.

### 3. Contextual Playground

**Definition:** A REPL bound to a selected object. The selected object is in scope; helper functions (`trace(obj)`, `examples(obj)`, `diff(obj, other)`, `render(obj, view="...")`) enable ad-hoc queries.

**When to use:** Prototyping queries and analysis before extracting them into permanent tools. v0 is Python-first: Python can call Rust via FFI, call LLM tools, and serialize quickly.

**harness-kit integration:** A workbench pane where selecting an object binds a Python REPL. The agent layer can use the same REPL for debugging ("what did the planner produce?") and for generating micro-tools on demand.

### 4. Custom View/Action/Search

**Definition:** Domain-specific renderers and operations attached to object types. Examples: "Show AST diff," "Replay agent plan," "Render state machine."

**When to use:** When the default view is insufficient and a custom tool answers the next question cheaply.

**harness-kit integration:** Components register views/actions in their bundle. The "Promote to Tool" workflow captures a playground script + selected object type, registers it as a custom view/action, and stores it with provenance (ticket id, author agent, commit hash).

### 5. Project Diary / Composed Narrative

**Definition:** Turn investigations into shareable, replayable "stories" built out of live objects. A narrative is a sequence of object refs + view selections + annotations.

**When to use:** Documenting debugging sessions, onboarding, and agent reasoning for stakeholders.

**harness-kit integration:** Phase artifacts and traces are the raw material. A narrative composes them into a linear story with timestamps, links to artifacts, and optional voice transcript. Stored as a first-class artifact (e.g., `narrative.v1`).

---

## V. Runtime Value Store

The **Runtime Value Store** is the "memory" behind moldability: a content-addressed store for interesting values collected from debugging, manual selection, savepoints, and sampling.

### Conceptual Model

```
┌─────────────────────────────────────────────────────────┐
│               Runtime Value Store                        │
├─────────────────────────────────────────────────────────┤
│  Content-addressed blobs (hash → bytes)                   │
│  Metadata index: ticket_id, trace_id, span_id,            │
│                  code_version, timestamp, object_type     │
│  Query: indexed search + filters                          │
└─────────────────────────────────────────────────────────┘
```

### Metadata Linking

Every stored value carries metadata:

| Field | Purpose |
|-------|---------|
| `ticket_id` | Which ticket produced or consumed this value |
| `trace_id` | W3C Trace Context trace ID |
| `span_id` | Span within the trace |
| `code_version` | Git commit or build hash |
| `object_type` | Schema type for the value |
| `provenance` | How it was captured (test, manual, savepoint, sampling) |

### Query Interface

The store supports:

- **Indexed search:** By `ticket_id`, `trace_id`, `object_type`, timestamp range
- **Filters:** Composite predicates on metadata
- **Deduplication:** Content-addressed storage (same bytes → same hash) enables efficient packing, inspired by Git

### Connection to harness-kit Artifacts

| harness-kit concept | Store integration |
|--------------------|-------------------|
| `artifacts_dir` (`.claude/artifacts/`) | Phase artifacts are also stored in the Runtime Value Store with full metadata. The artifacts dir is the primary namespace; the store adds queryability and dedup. |
| Phase outputs | Plan, iteration, test_run, review, etc. become queryable by ticket, phase, trace |
| Evidence artifacts | Test outputs, traces, snapshots, proofs, review findings — all linkable via metadata |

The store does *not* replace `artifacts_dir`; it extends it with a query layer and content-addressed deduplication for large-scale projects.

---

## VI. Integration with harness-kit

The following table maps moldable design concepts to harness-kit integration points.

| Concept | harness-kit integration point |
|---------------|------------------------------|
| **Errors as data (Invariant B)** | [workflow-contract](./workflow-contract.md) `PhaseResult<T>`; extend to FFI (`Result<T, E>` always propagates as structured error) and hot reload (`Reloaded` \| `Blocked`) |
| **Evidence artifacts (§6.1)** | [artifact-contracts](./artifact-contracts.md) and phase dual-output; add `example.v1` schema for tests that return objects |
| **Algebraic effects (§6.2)** | [basis.md](./basis.md) §VII; tool protocol for moldable actions — agents call explicit tools (build, test, query examples, reload) with typed inputs/outputs |
| **Component model (§4)** | [polyglot-architecture](./polyglot-architecture.md) `component_layers`; extend with evidence/examples in component bundle |
| **Content-addressed store (§5.2)** | `artifacts_dir` + Runtime Value Store; metadata links ticket, trace, code version |
| **Inspectability protocol (§9.1)** | Cross-language API; Rust implements via FFI, Python/TypeScript consume |
| **Observability** | [observability-standard](./observability-standard.md); traces/spans as moldable objects, W3C Trace Context propagation |

### Cross-References

| Topic | Specification |
|-------|---------------|
| CTT foundation, error as data, value semantics | [basis.md](./basis.md) §IX–X |
| Polyglot layering, component layers | [polyglot-architecture.md](./polyglot-architecture.md) |
| Phase gates, PhaseResult, determinism | [workflow-contract.md](./workflow-contract.md) |
| Trace/span propagation, REDACTED | [observability-standard.md](./observability-standard.md) |
| Artifact schemas, dual output | [artifact-contracts.md](./artifact-contracts.md) |

*Future specs:* Deeper formalization of component bundle schemas, tiered hot-reload strategies, state migration protocols, and quiescence guarantees.

---

## Related Specifications

- [basis.md](./basis.md) — Computational Type Theory and Algebraic Effects foundation
- [workflow-contract.md](./workflow-contract.md) — Universal workflow invariants, PhaseResult, error as data
- [polyglot-architecture.md](./polyglot-architecture.md) — Diplomat-based vertical integration, component layers
- [observability-standard.md](./observability-standard.md) — REDACTED telemetry, trace propagation
- [artifact-contracts.md](./artifact-contracts.md) — Artifact schemas and normalization
- [workflow-phases.md](../rules/workflow-phases.md) — Phase sequencing and gates
