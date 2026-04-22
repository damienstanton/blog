# Tiered Hot-Reload Strategy: State Migration Specification

This specification defines the **Tiered Hot-Reload Strategy** for live programming environments built with the harness-kit framework. Hot reload is treated as a **state migration problem**, not a code patching problem: each successful build produces a new *generation*, and reload activates that generation only after explicit quiescence, snapshot, migration, restore, and validation. The design aligns with the harness-kit's "errors as data" principle, CTT foundations in [basis.md](./basis.md), and the Moldable Design Canvas in [moldable-canvas.md](./moldable-canvas.md).

---

## I. Overview

### Core Principle: State Migration, Not Code Patching

Invariant D from the Moldable Design Canvas ([moldable-canvas.md](./moldable-canvas.md) §I) states: **hot reload is a state migration problem**. Dynamic software updating (DSU) research shows that safe live updates require explicit update points and explicit state transformation between versions. The platform treats hot reload as a controlled operation with quiescence points, state snapshot/rehydration, versioned schemas, and migration functions — not as ad-hoc code patching in place.

### Reload by Generation, Not by Mutation

Following the generation model below (§II): each successful build is a **new generation** of the component. The runtime never mutates code in place; it activates generation N+1 after deactivating generation N. This yields determinism and auditability.

### Connection to Error as Data

The [workflow-contract](./workflow-contract.md) mandates that all outcomes are structured data (Phase II.4). Hot reload extends this: reload returns either `Reloaded(new_generation_id)` or `Blocked(reason, recovery_actions)`. No exceptions, no crashes — every path is a sum-type variant that the caller can inspect and act on.

```typescript
// Conceptual ADT (language-agnostic)
type ReloadResult =
  | { status: "reloaded"; new_generation_id: string }
  | { status: "blocked"; reason: string; recovery_actions: string[] }
```

---

## II. Generation Model

Each successful build produces a **Generation** record with five fields. The runtime keeps a registry of generations and activates exactly one at a time.

### Generation Record Schema

```json
{
  "schema_version": "generation.v1",
  "generation_id": "a1b2c3d4",
  "interface_hash": "e5f6g7h8...",
  "state_schema_version": "1.2.0",
  "migration_function": "core/migrations/v1_to_v2.rs",
  "provenance": {
    "ticket_id": "TASK-063",
    "trace_id": "tr_xyz",
    "commit_sha": "abc123",
    "built_at": "2026-03-01T10:00:00Z"
  }
}
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `generation_id` | string | Unique identifier, content-hash based (first 8 hex chars of SHA-256 of build artifacts) |
| `interface_hash` | string | SHA-256 of the public API surface — used to detect backward-incompatible changes |
| `state_schema_version` | string | Semver for the state serialization format; drives migration logic |
| `migration_function` | string \| null | Optional path to migration code when schema version increases |
| `provenance` | object | Which ticket, trace, and commit produced this generation — links to workflow artifacts |

### Reload Semantics

**Reload** means "activate generation N+1." The orchestrator:

1. Deactivates the current generation (if any)
2. Loads generation N+1
3. Migrates state from the old schema to the new (if needed)
4. Restores state into the new generation
5. Runs smoke examples
6. Flips traffic to generation N+1

The old generation remains available for instant rollback until smoke examples pass.

---

## III. Tiered Strategy

Different layers of the polyglot stack have different reload characteristics. The strategy is tiered by difficulty and safety.

### Tier 0 — UI Hot Reload (TypeScript)

Use standard **HMR (Hot Module Replacement)** in the web/desktop stack (Vite, webpack, etc.). This is the easy win — no state migration protocol required beyond framework defaults. Component state is typically ephemeral; full page reload remains a fallback.

### Tier 1 — Python Agent Reload

Restart the agent process (or worker) with state restored from the runtime value store. Prefer **restart over `importlib.reload`** for complex graphs: `importlib.reload` has subtle semantics with module graphs, closures, and singletons that can produce inconsistent state. Restart + restore from a content-addressed value store is simpler and safer.

### Tier 2 — Rust Core Reload (The Hard Part)

Three options, ordered by recommended adoption path:

#### Option A (Recommended v0): Out-of-Process Core with Stable IPC

Run the Rust core as a **separate process** with a stable IPC protocol (e.g., JSON-RPC over stdio, Unix sockets, or gRPC). Reload = restart the process; state = snapshot/restore via serialization. This yields:

- **Strong fault isolation** — a crash in the core does not bring down the orchestrator
- **Simple reload** — kill old process, start new one with migrated state
- **No ABI instability** — the IPC boundary is the contract, not Rust layouts

#### Option B (Advanced Dev UX): In-Process Dylib Reload

Tools like [hot-lib-reloader](https://docs.rs/hot-lib-reloader/latest/hot_lib_reloader/) enable in-process dynamic library reload. **Dev-only.** Limitations:

- No signature changes across reload
- Type layout changes require care
- Non-generic exported functions only
- Careful handling of global state (or avoid it)

Use only when Option A is too slow for the dev loop and ABI + state migration discipline is solid.

#### Option C (Strong Isolation + Portability): WASM Core Runtime

Compile the Rust core to WebAssembly and run it via [Wasmtime](https://github.com/bytecodealliance/wasmtime) (or similar). The WASM module is **naturally replaceable** — swap the module binary; long-lived state resides in the host. Benefits:

- Sandboxing and portability
- Module replacement without process restart
- Clear reload boundary

### Decision Table

| Scenario | Tier | Option | When to Use |
|----------|------|--------|-------------|
| UI iteration | 0 | HMR | Always — standard tooling |
| Agent graph changes | 1 | Process restart + restore | Agent logic or tools changed |
| Rust core, production | 2 | A (out-of-process) | Default; maximizes safety |
| Rust core, dev speed critical | 2 | B (dylib) | Dev-only; accept limitations |
| Cross-platform / sandbox | 2 | C (WASM) | When isolation + portability matter |

---

## IV. State Migration Protocol

Every hot-reloadable component **must** expose three interface functions. These form the state migration protocol.

### Required Interface

| Function | Signature (conceptual) | Purpose |
|----------|------------------------|---------|
| `snapshot()` | `→ bytes` | Serialize current state to bytes |
| `restore(bytes)` | `→ Result<State, Error>` | Deserialize and reconstruct state |
| `migrate(from_version, snapshot_bytes)` | `→ Result<Vec<u8>, Error>` | Transform state from old schema to new |

### Per-Language Signatures

**Rust (trait):**

```rust
pub trait HotReloadable {
    fn snapshot(&self) -> Vec<u8>;
    fn restore(bytes: &[u8]) -> Result<Self, MigrationError> where Self: Sized;
    fn migrate(from_version: u32, snapshot_bytes: &[u8]) -> Result<Vec<u8>, MigrationError>;
}
```

**Python (protocol class):**

```python
class HotReloadable(Protocol):
    def snapshot(self) -> bytes: ...

    def restore(self, data: bytes) -> "HotReloadable":
        ...

    @staticmethod
    def migrate(from_version: int, snapshot_bytes: bytes) -> bytes:
        ...
```

**TypeScript (interfaces):**

```typescript
interface HotReloadable {
  snapshot(): Uint8Array;
  restore(data: Uint8Array): this;
}

interface HotReloadableClass {
  migrate(fromVersion: number, snapshotBytes: Uint8Array): Uint8Array;
}
```

### Error Handling

Migration failures return **structured errors**, never panic or throw uncaught exceptions. Errors include:

- `MigrationError::SchemaIncompatible { from, to }` — no migration path exists
- `MigrationError::DeserializationFailed { reason }` — corrupt or invalid bytes
- `MigrationError::ValidationFailed { field, reason }` — restored state failed validation

All error types are part of the `ReloadResult` / `Blocked` variant — the orchestrator receives structured data and can present recovery actions to the user.

---

## V. Reload Orchestrator

The orchestrator executes a 7-step sequence (see §V below).

### 7-Step Reload Sequence

1. **Request quiescence** — Finish in-flight requests; no new requests accepted until reload completes or aborts.
2. **Snapshot old generation** — Call `snapshot()` on the active component; persist bytes.
3. **Load new generation** — Load the new build (process, dylib, or WASM module).
4. **Migrate snapshot** — If `state_schema_version` changed, call `migrate(from_version, snapshot_bytes)`.
5. **Restore state** — Call `restore(migrated_bytes)` in the new generation.
6. **Run smoke examples** — Execute the component's Example Objects (from [moldable-canvas.md](./moldable-canvas.md)); all must pass.
7. **Flip traffic** — Route new requests to generation N+1; deallocate old generation.

### Failure Handling per Step

| Step | If Failure | Action |
|------|------------|--------|
| 1 (Quiescence) | Timeout | Abort reload; emit `Blocked("quiescence_timeout", ["increase timeout", "retry"])` |
| 2 (Snapshot) | Error | Abort; `Blocked("snapshot_failed", ["check component logs"])` |
| 3 (Load) | Load error | Abort; keep old generation active |
| 4 (Migrate) | Migration error | Abort; `Blocked("migration_failed", ["provide migration function", "downgrade"])` |
| 5 (Restore) | Restore error | Abort; `Blocked("restore_failed", ["fix state schema"])` |
| 6 (Smoke) | Example fails | **Rollback** — revert to old generation; `Blocked("smoke_failed", ["fix failing example"])` |
| 7 | N/A | Success — emit `Reloaded(new_generation_id)` |

### Rollback

The old generation remains **ready for instant rollback** until step 6 (smoke examples) passes. If smoke fails, traffic reverts to the old generation with no downtime. Only after smoke passes is the old generation deallocated.

### Observability

Each reload step emits a **trace span** per [observability-standard.md](./observability-standard.md). The span links old and new `generation_id` in metadata, enabling "why did this request see generation X?" debugging.

---

## VI. DSU Principles

### Kitsune-Style Dynamic Software Updating

The reload design draws on DSU research (e.g., [Kitsune](https://www.cs.umd.edu/~mwh/papers/kitsune.pdf)).

**Update points** — Explicit places in code where updates can safely occur. In this spec, the update point is the **quiescence point**: when no in-flight requests remain, the system is in a consistent state and safe to snapshot.

**State transformers** — Functions that convert old state representations to new ones. Here, `migrate(from_version, snapshot_bytes)` is the state transformer.

### Safety Property

**No update can produce an inconsistent state** — provided migration functions are total. If migration always returns either `Ok(new_bytes)` or `Err(...)`, and restore validates its input, the system never transitions to a half-migrated or corrupt state.

### Connection to CTT

Per [basis.md](./basis.md) §IV and §VIII: migration functions are **total functions**. They always produce a result or an explicit error — no panics, no undefined behavior. The CTT principle "error as data" (§VIII) requires that stuck or failing cases are sum-type variants (`Result`), not control-flow exceptions. Migration fits this exactly: `migrate(...) -> Result<Vec<u8>, MigrationError>`.

---

## VII. Integration with harness-kit

### Reload Events as Traces

Each generation change creates an **observability span** linking `old_generation_id` → `new_generation_id`. The [observability-standard](./observability-standard.md) maps workflow phases to spans; reload is a distinct span type (`reload`) with metadata: `generation_from`, `generation_to`, `duration_ms`, `status`.

### Generation Provenance in Artifacts

Artifacts produced by a workflow phase can reference their `generation_id`. This links implementation output (e.g., iteration artifacts) to the exact build that will be reloaded. See [artifact-standards](../rules/artifact-standards.md) for lineage and provenance conventions.

### Profile Configuration

Add `extensions.hot_reload` to the [project profile](./project-profile-schema.md):

```yaml
extensions:
  hot_reload:
    enabled: true
    tiers:
      ui: "hmr"                    # Tier 0: hmr | full_reload
      agentic: "process_restart"  # Tier 1: process_restart with state restore
      core: "out_of_process"      # Tier 2: out_of_process | dylib | wasm
    quiescence_timeout_ms: 5000
    migration_function_path: "migrations/"  # Directory containing migration functions
```

### Review Integration

The [review-rubrics](./review-rubrics.md) hot-reload checklist verifies:

- [ ] Reload happens at quiescence point
- [ ] Snapshot/restore exists; schema is versioned
- [ ] Migration function exists (or backward compatibility is guaranteed)
- [ ] Reload blocked with actionable guidance when migration fails
- [ ] Smoke examples run after reload
- [ ] Observability links old/new generations in traces

Review agents apply this checklist when changes affect hot-reloadable components.

### Cross-References

| Spec | Relationship |
|------|--------------|
| [workflow-contract.md](./workflow-contract.md) §II | Error as data; `ReloadResult` mirrors `PhaseResult` |
| [polyglot-architecture.md](./polyglot-architecture.md) | Layer structure; Tier 0/1/2 map to UI / agent / core |
| [observability-standard.md](./observability-standard.md) | Reload spans, trace context propagation |
| [moldable-canvas.md](./moldable-canvas.md) | Inspectability; Example Objects used as smoke tests |
| [basis.md](./basis.md) §IV, §VIII | Totality, error as data, migration as total function |

---

## Related Specifications

- [workflow-contract.md](./workflow-contract.md) — Error as data, phase contracts
- [polyglot-architecture.md](./polyglot-architecture.md) — Component layers, Diplomat FFI
- [observability-standard.md](./observability-standard.md) — Trace spans, REDACTED
- [moldable-canvas.md](./moldable-canvas.md) — Moldable DX, Invariant D, Example Objects
- [basis.md](./basis.md) — CTT foundations, totality, error as data
- [review-rubrics.md](./review-rubrics.md) — Hot-reload checklist for review agents
- [project-profile-schema.md](./project-profile-schema.md) — `extensions.hot_reload` schema
