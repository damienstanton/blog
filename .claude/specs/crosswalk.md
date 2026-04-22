# Crosswalk: Existing Docs → Generic Taxonomy

This appendix maps the **workflow rules and agent definitions** ([.claude/rules/](../.claude/rules/), [.claude/agents/](../.claude/agents/)) to the **generic taxonomy** in [.claude/specs/](./), providing auditable transformation lineage.

> **Migration complete.** The root-level `commands/` and `agents/` directories have been migrated to `.claude/rules/` and `.claude/agents/` respectively. References below use the new paths.

---

## I. Overview

The crosswalk ensures:
1. **Traceability**: Every original file maps to one or more generic specs
2. **Coverage**: Every generic spec derives from at least one original file
3. **Migration Path**: Teams can adopt generic specs incrementally
4. **Audit Trail**: Changes to original docs can be tracked against generic equivalents

---

## II. Command-Level Mapping

### [/new-task](../commands/new-task.md)

**Maps to:**
- **[.claude/specs/ticket-lifecycle.md](./ticket-lifecycle.md)** — State machine, schema, refinement Q&A process
- **[.claude/specs/artifact-contracts.md](./artifact-contracts.md)** — Ticket JSON/MD dual output
- **[.claude/specs/phase-orchestrator.md](./phase-orchestrator.md)** — Feature intake phase

**Transformations:**
- **Hardcoded paths** (`.claude/features/todo`) → Profile tokens (`{{TASK_TODO_DIR}}`)
- **Python SDK references** → Generic acceptance criteria templates
- **Fixed DoD checklist** → Profile-driven `lifecycle.definition_of_done_checklist`

**Migration:**
1. Extract ticket schema and state transitions → `ticket-lifecycle.md` Section III
2. Generalize refinement Q&A loop → `ticket-lifecycle.md` Section V
3. Define dual-output format → `artifact-contracts.md` (Ticket artifacts)

---

### [/do-task](../commands/do-task.md)

**Maps to:**
- **[.claude/specs/phase-orchestrator.md](./phase-orchestrator.md)** — All 7 phases (preflight → closure)
- **[.claude/specs/project-profile-schema.md](./project-profile-schema.md)** — Toolchain, governance, review graph
- **[.claude/specs/test-adapter.md](./test-adapter.md)** — Test execution and fixer loop
- **[.claude/specs/workflow-contract.md](./workflow-contract.md)** — Transition rules, error as data

**Transformations:**
- **Hardcoded commands** (`uv run pytest`, `make test`) → `profile.toolchain.test_cmd_full`
- **Fixed 7-agent review** → `profile.review_graph.agents` (configurable count/models)
- **Python-specific branch workflow** → Generic SCM abstraction (optional in profile)

**Migration:**
1. Extract phase sequence → `phase-orchestrator.md` Section II
2. Parameterize toolchain → `project-profile-schema.md` Section 3
3. Define review orchestration → `phase-orchestrator.md` Phase 5 + `review-rubrics.md`
4. Specify preflight checks → `phase-orchestrator.md` Phase 1

---

### [/run-tests-and-fix](../commands/run-tests-and-fix.md)

**Maps to:**
- **[.claude/specs/test-adapter.md](./test-adapter.md)** — Executor, parser, fixer interfaces
- **[.claude/specs/phase-orchestrator.md](./phase-orchestrator.md)** — Phase 4 (Testing) + Phase 6 (Triage)
- **[.claude/specs/project-profile-schema.md](./project-profile-schema.md)** — Skip/xfail policy, max iterations

**Transformations:**
- **Pytest-specific output parsing** → Generic `parser_interface` with `pytest_json` plugin
- **Skip=fail hardcoded** → `profile.governance.skip_policy` (fail | warn | allow)
- **Fixed max 3 iterations** → `profile.governance.max_fix_iterations`

**Migration:**
1. Abstract test executor → `test-adapter.md` Section II (Executor Interface)
2. Define parser plugins → `test-adapter.md` Section II (Parser Interface)
3. Specify fixer protocol → `test-adapter.md` Section II (Fixer Interface)
4. Extract remediation loop → `test-adapter.md` Section V

---

## III. Agent-Level Mapping

### [.claude/agents/test-runner.md](../.claude/agents/test-runner.md)

**Maps to:**
- **[.claude/specs/test-adapter.md](./test-adapter.md)** — Executor + Parser interfaces
- **[.claude/specs/artifact-contracts.md](./artifact-contracts.md)** — Test run artifact schema

**Transformations:**
- **Pytest + make commands** → Generic `profile.toolchain.test_cmd_full`
- **SDK-specific test paths** → `profile.layout.test_paths`
- **Output schema** → `artifact-contracts.md` Phase 4 (Testing)

**Migration:**
1. Generalize test execution logic → `test-adapter.md` Executor Interface
2. Define output normalization → `test-adapter.md` Parser Interface
3. Specify artifact schema → `artifact-contracts.md` (test_run.v1)

---

### [.claude/agents/test-fixer.md](../.claude/agents/test-fixer.md)

**Maps to:**
- **[.claude/specs/test-adapter.md](./test-adapter.md)** — Fixer interface
- **[.claude/specs/finding-schema.md](./finding-schema.md)** — Fix suggestion structure
- **[.claude/specs/phase-orchestrator.md](./phase-orchestrator.md)** — Phase 4 iteration loop

**Transformations:**
- **Pytest failure parsing** → Generic failure classification
- **Python-specific fixes** → Language-neutral fix templates
- **Ruff formatting** → `profile.toolchain.format_cmd`

**Migration:**
1. Abstract failure analysis → `test-adapter.md` Fixer Interface
2. Define fix schema → `finding-schema.md` (suggested_fix field)
3. Specify remediation loop → `test-adapter.md` Section V

---

### [.claude/agents/review-correctness-specification.md](../.claude/agents/review-correctness-specification.md)

**Maps to:**
- **[.claude/specs/review-rubrics.md](./review-rubrics.md)** — Specification Adherence lens
- **[.claude/specs/finding-schema.md](./finding-schema.md)** — Finding output format
- **[.claude/specs/artifact-contracts.md](./artifact-contracts.md)** — Review artifact schema

**Transformations:**
- **Python docstring checks** → Generic contract compliance rubric
- **Hardcoded severity mapping** → Parameterized category taxonomy
- **SDK-specific examples** → Language-neutral patterns

**Migration:**
1. Extract rubric items → `review-rubrics.md` Section III (Lens 1)
2. Generalize checklist → Remove Python-specific assumptions
3. Define finding output → `finding-schema.md` (full schema)

---

### [.claude/agents/review-correctness-defensive.md](../.claude/agents/review-correctness-defensive.md)

**Maps to:**
- **[.claude/specs/review-rubrics.md](./review-rubrics.md)** — Runtime Safety lens
- **[.claude/specs/finding-schema.md](./finding-schema.md)** — Category taxonomy (null_pointer_risk, etc.)

**Transformations:**
- **Python-specific hazards** (`None` checks) → Generic null safety rubric
- **Diff-centric analysis** → Generic change analysis with language plugins

**Migration:**
1. Extract safety checklist → `review-rubrics.md` Section III (Lens 2)
2. Create language plugins → `review-rubrics.md` Section V (heuristics)
3. Map categories → `finding-schema.md` Section VI (Correctness taxonomy)

---

### [.claude/agents/review-quality-structural.md](../.claude/agents/review-quality-structural.md)

**Maps to:**
- **[.claude/specs/review-rubrics.md](./review-rubrics.md)** — Maintainability (Structural) lens
- **[.claude/specs/finding-schema.md](./finding-schema.md)** — Quality category taxonomy

**Transformations:**
- **Python complexity thresholds** → Configurable per-language thresholds
- **Type annotation references** → Generic contract documentation checks

**Migration:**
1. Extract structural rubric → `review-rubrics.md` Section III (Lens 3)
2. Parameterize thresholds → `review-rubrics.md` (language_adjustments)
3. Map categories → `finding-schema.md` Section VI (Quality taxonomy)

---

### ~~agents/review-quality-structural-codex.md~~ (merged into .claude/agents/review-quality-structural.md)

**Maps to:**
- Same as `review-quality-structural.md`, but illustrates **multi-model** setup
- **[.claude/specs/project-profile-schema.md](./project-profile-schema.md)** — Review graph with model diversity

**Transformations:**
- Duplicate agent with different model → `profile.review_graph.agents[].model`

**Migration:**
1. Merge with structural rubric → Same `review-rubrics.md` lens
2. Configure model in profile → `project-profile-schema.md` Section 5

---

### [.claude/agents/review-quality-evolutionary.md](../.claude/agents/review-quality-evolutionary.md)

**Maps to:**
- **[.claude/specs/review-rubrics.md](./review-rubrics.md)** — Maintainability (Evolutionary) lens
- **[.claude/specs/finding-schema.md](./finding-schema.md)** — Technical debt categories

**Transformations:**
- **Coupling analysis** → Generic module dependency checks
- **Test coverage** → Language-agnostic coverage expectations

**Migration:**
1. Extract evolutionary rubric → `review-rubrics.md` Section III (Lens 4)
2. Define debt categories → `finding-schema.md` Section VI (Quality taxonomy)

---

### ~~agents/review-quality-evolutionary-codex.md~~ (merged into .claude/agents/review-quality-evolutionary.md)

**Maps to:**
- Same as `review-quality-evolutionary.md` (multi-model variant)

---

### [.claude/agents/review-docs-consistency.md](../.claude/agents/review-docs-consistency.md)

**Maps to:**
- **[.claude/specs/review-rubrics.md](./review-rubrics.md)** — Documentation lens
- **[.claude/specs/finding-schema.md](./finding-schema.md)** — Documentation category taxonomy

**Transformations:**
- **Hardcoded doc paths** (`README.md`, `docs/`) → `profile.layout.doc_paths`
- **Python docstring style** → Configurable `profile.extensions.doc_style`

**Migration:**
1. Extract docs rubric → `review-rubrics.md` Section III (Lens 5)
2. Parameterize doc locations → `project-profile-schema.md` Section 2
3. Map categories → `finding-schema.md` Section VI (Documentation taxonomy)

---

## IV. Cross-Cutting Concerns

### Basis: [basis.md](../basis.md)

**Maps to:**
- **[.claude/specs/workflow-contract.md](./workflow-contract.md)** — Foundation mapping (CTT § → workflow invariant)

**Key Translations:**
| CTT Concept (basis.md §) | Workflow Analog |
|---------------------------|-----------------|
| Abstract Syntax / Domain (§I) | Input contracts (ADT-style schema validation) |
| Operational Semantics / Dynamics (§II) | Transition rules (deterministic state machines, $E \mapsto E'$) |
| Judgemental Equality / Verifier (§III) | Validation rules (correctness checks, $M \doteq M' \in A$) |
| Functionality (§IV) | Compositional determinism (equal inputs → equal outputs across phases) |
| Propositions as Types (§V) | Schemas as specifications; conforming artifacts as proofs |
| Algebraic Effects (§VII) | Structured side-effect handling ($Op : B \times A^C \to A$) |
| Totality (§VIII) | Max iterations, timeouts, gas limits |
| Error as Data (§VIII) | `Result<T, E>` / `PhaseResult<T>` pattern in all phases |
| Design Consequences (§IX) | Value semantics, sum types for variants, no mutative inheritance or mixins |
| Agentic Stack (§X) | Rust (core logic) + Python (agentic orchestration) + TypeScript (UI/verification) |

---

## V. Migration Dependency Graph

```
basis.md
    ↓
workflow-contract.md
    ↓
    ├─→ project-profile-schema.md
    │       ↓
    ├─→ ticket-lifecycle.md ← .claude/commands/new-task.md
    │       ↓
    └─→ phase-orchestrator.md ← .claude/commands/do-task.md
            ↓
            ├─→ test-adapter.md ← .claude/agents/test-runner.md + .claude/agents/test-fixer.md
            │       ↓
            └─→ review-rubrics.md ← .claude/agents/review-*.md
                    ↓
                finding-schema.md
                    ↓
                artifact-contracts.md ← All phases
                    ↓
                normalization-rules.md
```

**Migration Order:**
1. Start with `workflow-contract.md` and `project-profile-schema.md` (foundation)
2. Adopt `ticket-lifecycle.md` for feature intake
3. Migrate test execution to `test-adapter.md`
4. Convert review agents to `review-rubrics.md` + `finding-schema.md`
5. Integrate full `phase-orchestrator.md`
6. Enforce `artifact-contracts.md` and `normalization-rules.md` for pipeline

---

## VI. Verification Matrix

| Original File | Generic File(s) | Transformation Complete? | Artifacts Compatible? |
|---------------|----------------|--------------------------|----------------------|
| .claude/commands/new-task.md | ticket-lifecycle.md, artifact-contracts.md | ✅ | ✅ |
| .claude/commands/do-task.md | phase-orchestrator.md, project-profile-schema.md | ✅ | ✅ |
| .claude/commands/run-tests-and-fix.md | test-adapter.md, phase-orchestrator.md | ✅ | ✅ |
| .claude/agents/test-runner.md | test-adapter.md | ✅ | ✅ |
| .claude/agents/test-fixer.md | test-adapter.md | ✅ | ✅ |
| .claude/agents/review-correctness-specification.md | review-rubrics.md (Lens 1) | ✅ | ✅ |
| .claude/agents/review-correctness-defensive.md | review-rubrics.md (Lens 2) | ✅ | ✅ |
| .claude/agents/review-quality-structural.md | review-rubrics.md (Lens 3) | ✅ | ✅ |
| ~~agents/review-quality-structural-codex.md~~ | Merged: multi-model via profile | ✅ | ✅ |
| .claude/agents/review-quality-evolutionary.md | review-rubrics.md (Lens 4) | ✅ | ✅ |
| ~~agents/review-quality-evolutionary-codex.md~~ | Merged: multi-model via profile | ✅ | ✅ |
| .claude/agents/review-docs-consistency.md | review-rubrics.md (Lens 5) | ✅ | ✅ |

---

## VII. Validation Procedure

To verify a transformation is complete:

1. **Extract Original Intent**: Read original doc, list assumptions and constraints
2. **Find Generic Equivalent**: Locate corresponding section in generic specs
3. **Compare Coverage**: Ensure all logic/rules from original appear in generic (possibly parameterized)
4. **Instantiate Profile**: Create a project profile that reproduces original behavior
5. **Run Side-by-Side**: Execute both original and generic workflows, compare outputs
6. **Check Artifact Schema**: Validate outputs conform to `artifact-contracts.md`

**Example: Validating test-runner.md transformation**

```bash
# Original behavior
cd langfuse-python-sdk
uv run pytest tests/ -v --json-report

# Generic behavior
cd langfuse-python-sdk
./workflow-engine.py run-phase testing \
    --profile .claude/profiles/langfuse-python.yaml \
    --ticket FEAT-123

# Compare outputs
diff original_output.json .claude/artifacts/FEAT-123_test_run.json
# → Should match modulo timestamps and normalized fields
```

---

## VIII. Code Examples: Before & After

### Example 1: Test Command

**Before (Hardcoded):**
```python
# .claude/agents/test-runner.md implementation
def run_tests():
    result = subprocess.run(
        ["uv", "run", "pytest", "tests/", "-v"],
        capture_output=True
    )
    return parse_pytest_output(result.stdout)
```

**After (Generic):**
```python
# .claude/specs/test-adapter.md implementation
def run_tests(profile: ProjectProfile):
    cmd = profile.toolchain.test_cmd_full
    result = subprocess.run(
        cmd.split(),
        cwd=profile.identity.project_root,
        capture_output=True
    )
    parser = get_parser(profile.toolchain.test_output_format)
    return parser.parse(result.stdout, profile)
```

---

### Example 2: Review Agent Prompt

**Before (Python-specific):**
```markdown
# .claude/agents/review-correctness-defensive.md

Review the diff for potential runtime errors:
- Check for None dereferences
- Look for missing try/except blocks
- Verify dict.get() usage for optional keys
```

**After (Generic):**
```markdown
# .claude/specs/review-rubrics.md (Runtime Safety Lens)

Review the diff for potential runtime errors:
- Check for {{NULL_TYPE}} dereferences
- Look for missing {{ERROR_HANDLING_PATTERN}} blocks
- Verify {{SAFE_ACCESS_PATTERN}} usage for optional values

Language-specific heuristics:
{{#if LANGUAGE == "Python"}}
  NULL_TYPE: None
  ERROR_HANDLING_PATTERN: try/except
  SAFE_ACCESS_PATTERN: dict.get()
{{/if}}
{{#if LANGUAGE == "Rust"}}
  NULL_TYPE: None (Option type)
  ERROR_HANDLING_PATTERN: Result<T, E> or ?
  SAFE_ACCESS_PATTERN: .get() or pattern matching
{{/if}}
```

---

## IX. Rollout Strategy

### Phase 1: Pilot (Weeks 1-2)
- Implement `workflow-contract.md` and `project-profile-schema.md`
- Create profile for **one pilot project** (e.g., Rust library)
- Validate profile against schema

### Phase 2: Core Workflows (Weeks 3-4)
- Migrate `new-task` → `ticket-lifecycle.md`
- Migrate `run-tests-and-fix` → `test-adapter.md`
- Run pilot project through new workflows

### Phase 3: Review System (Weeks 5-6)
- Convert all 7 review agents → `review-rubrics.md` + language plugins
- Validate findings schema compatibility

### Phase 4: Full Integration (Weeks 7-8)
- Deploy `phase-orchestrator.md` end-to-end
- Enforce `artifact-contracts.md` and `normalization-rules.md`
- Run parallel execution: old workflow vs. new (validate equivalent)

### Phase 5: Production (Week 9+)
- Decommission original docs (mark as legacy)
- All new projects use generic specs only
- Maintain backward compatibility adapters for 3 months

---

## X. Appendix: Token Reference Table

| Original Hardcoded Value | Generic Token | Profile Location |
|--------------------------|---------------|------------------|
| `.claude/features/todo` | `{{TASK_TODO_DIR}}` | `layout.task_todo_dir` |
| `uv run pytest tests/` | `{{TEST_CMD_FULL}}` | `toolchain.test_cmd_full` |
| `make test` | `{{TEST_CMD_FULL}}` | `toolchain.test_cmd_full` |
| `cargo test --all` | `{{TEST_CMD_FULL}}` | `toolchain.test_cmd_full` |
| `ruff format .` | `{{FORMAT_CMD}}` | `toolchain.format_cmd` |
| `SKIP=FAIL` | `{{SKIP_POLICY}}` | `governance.skip_policy` |
| 7 review agents | `{{REVIEW_AGENTS}}` | `review_graph.agents` |
| `langfuse-python-sdk` | `{{PROJECT_NAME}}` | `identity.project_name` |
| `Python` | `{{LANGUAGE}}` | `identity.language` |

---

This crosswalk ensures every original file has a clear path to the generic taxonomy, enabling **incremental adoption** and **auditability** throughout the migration.
