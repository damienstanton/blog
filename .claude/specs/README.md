# Generic Workflow System: Language-Agnostic Automation for Any Project $L$

This directory contains the **complete specification** for a language-agnostic workflow system grounded in the [Computational Type Theory (CTT)](../basis.md) framework. It enables feature development, testing, and code review for any language/project $L$ through configurable profiles and deterministic execution.

---

## Overview

The system generalizes workflow patterns from [.claude/rules/](../.claude/rules/) and [.claude/agents/](../.claude/agents/) into reusable primitives that accept **any language** as a parameter. Each feature is implemented as a composition of:

1. **LLM subagent/command prompt actions** (flexible, language-aware)
2. **Deterministic code generation pipeline** (external, consumes structured artifacts)

**Key Properties:**
- **Language-Agnostic**: Works with Rust, Python, Go, Java, TypeScript, etc.
- **Deterministic**: Identical inputs produce byte-stable outputs
- **Verifiable**: Every step adheres to formal contracts (input/output schemas)
- **Composable**: Phases combine via sequential/parallel/conditional primitives
- **Traceable**: Full audit trail from request → artifacts

---

## Document Index

### Foundation

1. **[workflow-contract.md](./workflow-contract.md)**  
   Maps CTT concepts (domain, dynamics, verifier) to workflow invariants. Defines universal contracts: `input_contract`, `transition_rules`, `validation_rules`, `error_as_data`.

2. **[project-profile-schema.md](./project-profile-schema.md)**  
   Configuration schema for instantiating workflows for a specific project. Includes:
   - Identity (project name, language, runtime)
   - Layout (src/test/doc paths)
   - Toolchain (install/test/format/lint commands)
   - Governance (skip/xfail policy, max iterations, auto-fix rules)
   - Review graph (agents, models, batches)
   - Lifecycle (ticket states, transitions, templates)

---

### Core Processes

3. **[ticket-lifecycle.md](./ticket-lifecycle.md)**  
   Generic task management: state machine (todo → refined → in_progress → done), ticket schema, refinement Q&A process. Language-neutral acceptance criteria and DoD templates.

4. **[phase-orchestrator.md](./phase-orchestrator.md)**  
   End-to-end implementation orchestration: 7 phases (preflight, planning, iteration, testing, review, triage, closure). Each phase is a deterministic state machine with explicit error handling.

5. **[test-adapter.md](./test-adapter.md)**  
   Pluggable test execution: executor (run commands), parser (normalize output), fixer (remediate failures). Supports arbitrary test frameworks via adapter pattern.

---

### Quality Assurance

6. **[review-rubrics.md](./review-rubrics.md)**  
   Language-neutral review prompts for 5 lenses:
   - Specification Adherence (correctness)
   - Runtime Safety (defensive programming)
   - Maintainability (structural quality)
   - Maintainability (evolutionary debt)
   - Documentation (consistency)

   Uses language-specific heuristic plugins for precise checks.

7. **[finding-schema.md](./finding-schema.md)**  
   Universal format for review findings: severity, category, location, evidence, confidence, suggested fix. Enables deterministic deduplication and triage across agents/models.

---

### Artifacts & Pipeline

8. **[artifact-contracts.md](./artifact-contracts.md)**  
   Dual-output format (JSON + Markdown) for every phase. JSON is machine-readable with versioned schemas; Markdown is human-readable. Defines exact structure for preflight, plan, iteration, test, review, triage, and closure artifacts.

9. **[normalization-rules.md](./normalization-rules.md)**  
   Deterministic artifact processing: lexicographic key ordering, canonical whitespace, timestamp policies, path normalization, stable array sorting, content-based ID generation. Ensures byte-stable outputs for deterministic pipeline ingestion.

---

### Migration

10. **[crosswalk.md](./crosswalk.md)**  
   Maps existing workflow rules ([.claude/rules/](../.claude/rules/)) and agent definitions ([.claude/agents/](../.claude/agents/)) to generic specs. Provides transformation guide, validation matrix, and rollout strategy.

---

### Extensions

11. **[polyglot-architecture.md](./polyglot-architecture.md)**  
   Diplomat-based vertical integration system for building complete features spanning multiple languages. Enables Rust core → TypeScript UI, Python agents, C/C++ embedded, Tauri desktop apps, all from a single source of truth.

12. **[example-tauri-profile.md](./example-tauri-profile.md)**  
   Complete project profile demonstrating Tauri 2 + Rust + TypeScript integration with pnpm, Vite, and vitest. Shows how to build cross-platform desktop applications with type-safe IPC between Rust backend and React frontend.

13. **[workspace-plasticity.md](./workspace-plasticity.md)**  
   Explains how the polyglot system enables a single workspace to "mold itself" into any output form (CLI, desktop, web, mobile, embedded, Arduino, ESP32) through the harness-kit, all from one Rust core implementation.

14. **[template-bootstrap.md](./template-bootstrap.md)**  
   Template-based project bootstrapping system. Users clone approved template repositories into `.claude/context/`, and the system discovers, analyzes (via manifest or inference), composes (mapping to polyglot layers), and instantiates them into the project root, auto-generating a project profile. Supports single and multi-template composition.

---

### Versioning

15. **[versioning.md](./versioning.md)**  
   Semantic versioning policy for the harness-kit framework. Defines what constitutes major, minor, and patch changes for a framework of specs, agents, commands, and configuration schemas. Documents the `.claude/VERSION` file format, changelog conventions, pre-1.0 expectations, and release process.

---

### Observability

16. **[observability-standard.md](./observability-standard.md)**  
   Maps the REDACTED AI Telemetry Spec to harness-kit concepts. Defines how workflow phases, subagent invocations, and user code emit distributed traces via Langfuse. Covers sensitivity classification (PUBLIC/INTERNAL/CONFIDENTIAL/HIGHLY_CONFIDENTIAL), data governance compliance metadata, W3C Trace Context propagation, and framework integration patterns (FastAPI, LangGraph, LangChain).

17. **REDACTED AI Telemetry Spec** *(external)*  
   An external telemetry specification defining the data model (traces, observations, span types), sensitivity classification, data governance consent metadata, event taxonomy, and propagation protocols (HTTP, MCP, A2A). Referenced by `observability-standard.md`.

---

## Quick Start

### 1. Create a Project Profile

```yaml
# .claude/profiles/my-rust-project.yaml
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
  test_cmd_full: "cargo test --all -- --nocapture"
  test_cmd_targeted: "cargo test {target} -- --nocapture"
  test_output_format: "cargo_json"
  format_cmd: "cargo fmt --all"
  lint_cmd: "cargo clippy --all -- -D warnings"

governance:
  skip_policy: "warn"
  xfail_policy: "allow"
  autofix_confidence_rules:
    - {condition: "confidence >= 0.9", action: "apply_automatically"}
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
  required_fields: ["title", "description", "acceptance_criteria"]
```

### 2. Validate the Profile

```bash
./tools/validate-profile.py .claude/profiles/my-rust-project.yaml \
    --schema .claude/specs/project-profile-schema.json
```

### 3. Run a Workflow

```bash
# Feature intake
./workflow-engine.py create-ticket \
    --profile .claude/profiles/my-rust-project.yaml \
    --description "Add retry logic to HTTP client"

# Implementation
./workflow-engine.py implement \
    --profile .claude/profiles/my-rust-project.yaml \
    --ticket TASK-001

# Artifacts generated in .claude/artifacts/
ls .claude/artifacts/
# TASK-001_preflight.json
# TASK-001_plan.json
# TASK-001_test_run.json
# TASK-001_review.json
# TASK-001_summary.json
# ... (+ .md versions)
```

### 4. Validate Artifacts

```bash
# Check schema conformance and normalization
./tools/validate-artifact.py \
    .claude/artifacts/TASK-001_review.json \
    --schema .claude/specs/schemas/review.v1.schema.json
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     User Request                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│     Template Bootstrap (template-bootstrap.md)  [Phase 0]  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ Discover     │───▶│ Compose      │───▶│ Instantiate  │  │
│  │ .claude/context/     │    │ (layers)     │    │ → project    │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│  Output: project root + .claude/profiles/<project>.yaml     │
│  Condition: skipped if project root already populated     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│           Feature Intake (ticket-lifecycle.md)              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ Capture      │───▶│ Refinement   │───▶│ Finalize     │  │
│  │ (draft)      │    │ (Q&A loop)   │    │ (state=done) │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│  Output: ticket.json + ticket.md                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│       Phase Orchestrator (phase-orchestrator.md)            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │Preflight │─▶│ Planning │─▶│Iteration │─▶│ Testing  │   │
│  └──────────┘  └──────────┘  └────┬─────┘  └────┬─────┘   │
│                                    │             │          │
│                          ┌─────────▼─────────────▼─────┐   │
│                          │   Test Adapter (executor,   │   │
│                          │   parser, fixer)            │   │
│                          └─────────┬───────────────────┘   │
│                                    │                        │
│  ┌──────────┐  ┌──────────┐  ┌────▼─────┐  ┌──────────┐   │
│  │ Closure  │◀─│  Triage  │◀─│  Review  │  │          │   │
│  └──────────┘  └──────────┘  └────┬─────┘  │          │   │
│                                    │        │          │   │
│                          ┌─────────▼────────▼─────────┐   │
│                          │   Review Rubrics (5 lenses,│   │
│                          │   N agents, M models)      │   │
│                          └─────────┬──────────────────┘   │
│                                    │                       │
│                          ┌─────────▼──────────────────┐   │
│                          │ Finding Schema (structured │   │
│                          │ observations)              │   │
│                          └────────────────────────────┘   │
│                                                             │
│  All phases emit: JSON + Markdown artifacts                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│    Normalization (normalization-rules.md)                   │
│  - Lexicographic key ordering                               │
│  - Stable timestamps                                        │
│  - Deterministic IDs                                        │
│  - Canonical whitespace                                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│    External Deterministic Code Generation Pipeline          │
│  (Outside scope: consumes normalized JSON artifacts)        │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Design Decisions

### 1. Why CTT as Foundation?

The [basis.md](../basis.md) CTT framework (Harper, OPLSS 2018; building on Martin-Löf and Constable/NuPRL) provides a rigorous foundation where **types are specifications of program behavior**. Each CTT concept maps directly to a workflow invariant (see [workflow-contract.md](./workflow-contract.md) §I):

- **Domain (§I)**: Valid workflow inputs are defined as inductive ADTs with clear schemas — just as CTT defines expressions inductively
- **Dynamics (§II)**: Phase transitions are deterministic state machines — mirroring CTT's transition system $E \mapsto E'$
- **Verifier (§III)**: Validation gates check that outputs meet specifications — mirroring judgemental equality $M \doteq M' \in A$ verified by evaluation to canonical forms
- **Functionality (§IV)**: Phases respect equality of inputs (compositional determinism) — mirroring CTT's Fundamental Lemma that families respect equality of indices
- **Propositions as Types (§V)**: Artifact schemas *are* specifications; conforming artifacts *are* proofs — the Curry-Howard correspondence applied to workflow artifacts
- **Algebraic Effects (§VII)**: Side effects (tool calls, I/O, test execution) are structured operations with parameter types and continuations — grounded in Bauer's effect signatures
- **Totality (§VIII)**: Bounded computation via max iterations and gas limits — no infinite loops
- **Error as Data (§VIII)**: Failures are explicit sum-type variants, not exceptions — stuck terms are data, never crashes
- **Design Consequences (§IX)**: Value semantics are required by the canonical forms; sum types replace class hierarchies; product types replace mixins; algebraic effects replace implicit mutation. Mutative inheritance and mixins are structurally incompatible with judgemental equality and functionality.
- **Agentic Stack (§X)**: Rust (canonical core logic, property-tested), Python (agentic effect orchestration, LLM/tool/data), and TypeScript (structural verification surface, UI) form the CTT-optimal language triad for agent systems, with state-of-the-art patterns deeply supported for each.

This translates to workflows that are **predictable**, **auditable**, and **fail-safe** — and to generated code that is compositional, structurally verifiable, and free of hidden dispatch or implicit state coupling.

---

### 2. Why Dual Outputs (JSON + Markdown)?

- **JSON**: Deterministic, machine-readable, schema-validated. Ideal for pipeline ingestion, aggregation, and automated tooling.
- **Markdown**: Human-readable, diff-friendly, embeddable in PRs/docs. Ideal for human review and audit trails.

Both are generated from the same source of truth, ensuring consistency.

---

### 3. Why Pluggable Test Adapters?

Test frameworks vary wildly across languages:
- Rust: `cargo test` with JSON output
- Python: `pytest` with JSON or JUnit XML
- Go: Plain text with structured prefixes
- JavaScript: `jest` with native JSON

A **universal adapter interface** (executor/parser/fixer) allows the same orchestration logic to work with any runner, while language-specific parsers handle output normalization.

---

### 4. Why Language-Specific Heuristic Plugins?

Some code quality checks are inherently language-dependent:
- Null safety: `unwrap()` in Rust vs. `None` checks in Python
- Resource cleanup: RAII in Rust vs. `with` statements in Python

The **plugin architecture** keeps core rubrics language-neutral while delegating precise checks to language experts.

---

### 5. Why Review Graph Configuration?

Different projects need different trade-offs:
- **Startups**: 2-3 agents, single model, fast iteration
- **Critical systems**: 7+ agents, multiple models, high rigor

Making the review graph **configurable** via profile allows teams to adjust cost/latency/quality dynamically without rewriting prompts.

---

## Validation Strategy

### Profile Validation

```bash
# Schema check
jsonschema -i .claude/profiles/my-project.yaml .claude/specs/project-profile-schema.json

# Toolchain check
./tools/check-toolchain.py .claude/profiles/my-project.yaml
# → Verifies all commands are executable

# Lifecycle soundness
./tools/check-lifecycle.py .claude/profiles/my-project.yaml
# → Verifies state machine is acyclic, all states reachable
```

### Artifact Validation

```bash
# Per-artifact schema check
./tools/validate-artifact.py .claude/artifacts/TASK-001_review.json \
    --schema .claude/specs/schemas/review.v1.schema.json

# Normalization check
./tools/check-normalized.py .claude/artifacts/TASK-001_review.json
# → Verifies keys sorted, timestamps canonical, etc.

# Lineage check
./tools/check-lineage.py .claude/artifacts/TASK-001_summary.json
# → Verifies all referenced prior artifacts exist
```

### End-to-End Validation

```bash
# Run workflow with two profiles (same ticket)
./workflow-engine.py implement --profile .claude/profiles/rust-project.yaml --ticket TASK-001
./workflow-engine.py implement --profile .claude/profiles/python-project.yaml --ticket TASK-001

# Compare artifact schemas (should be identical structure, different content)
diff <(jq 'keys' rust-artifacts/TASK-001_review.json) \
     <(jq 'keys' python-artifacts/TASK-001_review.json)
# → Should produce no diff (same keys)
```

---

## Migration Path from Existing Docs

See [crosswalk.md](./crosswalk.md) for detailed mapping. Summary:

1. **Phase 1**: Create profile for existing project
2. **Phase 2**: Migrate ticket lifecycle (new-task)
3. **Phase 3**: Migrate test execution (run-tests-and-fix)
4. **Phase 4**: Migrate review agents (7 agents → 5 lenses)
5. **Phase 5**: Full orchestrator deployment (do-task)
6. **Phase 6**: Enforce normalization & artifact contracts

Each phase can be adopted incrementally; original docs remain functional during migration.

---

## Extending the System

### Adding a New Language

1. **Profile**: Create `.claude/profiles/my-new-lang-project.yaml`
2. **Test Parser**: Implement parser plugin in `adapters/test_parsers/`
3. **Heuristics**: Add language plugin in `adapters/review_heuristics/`
4. **Validate**: Run through orchestrator, check artifact schemas match

Example:
```python
# adapters/test_parsers/elixir_exunit.py
class ExUnitParser(TestParser):
    def parse(self, raw: str, profile: ProjectProfile) -> TestResults:
        # Parse ExUnit output: "1 test, 0 failures"
        ...
```

### Adding a New Review Lens

1. **Define Rubric**: Add section to `review-rubrics.md`
2. **Map Categories**: Add to `finding-schema.md` taxonomy
3. **Configure Profile**: Add agent to `review_graph.agents`
4. **Validate Output**: Ensure findings conform to `finding.v1` schema

---

## FAQ

**Q: Can I use this for non-code projects?**  
A: Yes, if you can define a profile with appropriate toolchain commands. The system is language-agnostic, not domain-specific. Has been used for LaTeX docs, infrastructure-as-code, etc.

**Q: Does this replace GitHub Actions / CI/CD?**  
A: No, this focuses on **feature development workflow** (intake → implementation → review). CI/CD executes tests in production; this executes them during development with auto-remediation. They complement each other.

**Q: How do I handle proprietary test frameworks?**  
A: Implement a custom test parser (see `test-adapter.md` Section II). As long as you can map to the normalized `TestResults` schema, the rest of the system works unchanged.

**Q: What if my language doesn't have a linter?**  
A: Set `profile.toolchain.lint_cmd` to `"true"` (no-op). The orchestrator skips lint validation but continues with other checks.

**Q: Can I run this offline?**  
A: LLM subagents require API access (OpenAI, Anthropic, etc.). For offline use, deploy a local LLM server and point `review_graph.agents[].model` to it.

---

## Dependencies

- **Python 3.10+** (for orchestrator, validation tools)
- **JSON Schema validator** (`jsonschema` library)
- **Diff utilities** (`difflib` or system `diff`)
- **LLM API access** (for review agents)
- **Language-specific toolchains** (Rust: `cargo`, Python: `pytest`, etc.)

---

## Contributing

To add a new component:
1. Follow the structure in existing specs (see [workflow-contract.md](./workflow-contract.md) for template)
2. Define input/output contracts explicitly
3. Provide language-agnostic examples + 2+ language-specific instantiations
4. Add validation rules and JSON schema
5. Update [crosswalk.md](./crosswalk.md) if migrating from existing doc

---

## License

This specification is licensed under the same terms as the parent project. See [LICENSE](../LICENSE) if available.

---

## Changelog

- **2026-02-17**: REDACTED observability integration
  - Added `observability-standard.md` — maps REDACTED telemetry to harness-kit phases/agents
  - Added REDACTED AI Telemetry Spec (now fetched externally via the REDACTED configuration)
  - Profile schema extended with full `extensions.observability` (Langfuse, identity, sensitivity, CDO, compliance)
  - Phase orchestrator emits REDACTED traces/spans when observability enabled
  - Template bootstrap verifies REDACTED dependencies in Python templates
  - Python agentic agent updated with mandatory REDACTED SDK patterns

- **2026-02-17**: Template bootstrap system
  - Added `template-bootstrap.md` — template discovery, analysis, composition, instantiation
  - Phase 0 (Bootstrap) added to phase orchestrator
  - Profile schema extended with `layout.code_dir`, `layout.templates_dir`, `extensions.bootstrap`
  - Supports single and multi-template composition into polyglot projects

- **2026-02-15**: Initial release of generic workflow system
  - Core specifications
  - Full Python SDK → Generic migration coverage
  - Validation tooling and examples

---

For questions or discussions, see the project repository or contact the maintainers.
