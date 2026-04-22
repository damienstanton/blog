# Language-Neutral Review Rubrics: Generic Agent Prompts

This specification defines how to construct **language-agnostic review prompts** for all review agents, generalizing [.claude/agents/](../.claude/agents/) prompts to work with any project $L$. Each rubric produces findings conforming to the [finding schema](./finding-schema.md).

---

## I. Overview

Review agents assess code changes through different **lenses** (correctness, quality, documentation). To make these reviews language-neutral:

1. **Replace language-specific examples** with parameterized patterns
2. **Use project profile tokens** for toolchain/structure references
3. **Define universal heuristics** with language-specific plugins
4. **Emit standardized findings** regardless of source language

---

## II. Universal Review Prompt Template

All review agents follow this structure:

```markdown
# {{AGENT_NAME}}: {{LENS}} Review

**Project:** {{PROJECT_NAME}} ({{LANGUAGE}})  
**Model:** {{MODEL}}  
**Lens:** {{LENS}}

---

## Context

You are reviewing code changes for a {{LANGUAGE}} project. Your focus is **{{LENS}}**.

**Changes:**
{{DIFF}}

**Ticket:**
{{TICKET_DESCRIPTION}}

**Acceptance Criteria:**
{{ACCEPTANCE_CRITERIA}}

**Project Profile:**
- Language: {{LANGUAGE}}
- Test Framework: {{TEST_OUTPUT_FORMAT}}
- Lint Tool: {{LINT_CMD}}
- Documentation Style: {{DOC_STYLE}}

---

## Review Checklist

{{RUBRIC_ITEMS}}

---

## Instructions

1. Read the diff and ticket context
2. Apply each checklist item systematically
3. For each issue found:
   - Classify severity (critical/high/medium/low/info)
   - Identify category (from taxonomy)
   - Provide evidence (snippet + explanation)
   - Suggest fix if possible (with confidence & risk)
4. Output findings as JSON array conforming to `finding.v1` schema
5. If no issues found, output empty array `[]`

---

## Output Format

```json
[
  {
    "schema_version": "finding.v1",
    "id": "{{GENERATE_ID}}",
    "agent_id": "{{AGENT_ID}}",
    "severity": "...",
    "category": "...",
    // ... rest of finding schema
  }
]
```
```

---

## III. Rubric Definitions by Lens

### Lens 1: Specification Adherence

**Generalizes:** [.claude/agents/review-correctness-specification.md](../.claude/agents/review-correctness-specification.md)

**Purpose:** Verify implementation matches stated requirements (ticket ACs, API contracts, specs).

**Checklist:**
```yaml
rubric_items:
  - id: "ac_coverage"
    question: "Does the implementation address all acceptance criteria?"
    severity_if_violated: "high"
    category: "spec_violation"
    language_agnostic: true
    
  - id: "contract_compliance"
    question: "Do function signatures match documented contracts (params, return types, exceptions)?"
    severity_if_violated: "high"
    category: "contract_violation"
    language_specific_checks:
      rust: "Check trait implementations and lifetime annotations"
      python: "Check type hints match docstring annotations"
      go: "Check interface conformance"
    
  - id: "edge_cases"
    question: "Are edge cases mentioned in specs handled (empty input, null, max values)?"
    severity_if_violated: "high"
    category: "edge_case_missing"
    examples:
      generic: "Empty list, null pointer, overflow"
      rust: "None variant, empty Vec, integer overflow"
      python: "None, empty list/dict, division by zero"
    
  - id: "error_conditions"
    question: "Are all specified error conditions properly returned/raised?"
    severity_if_violated: "medium"
    category: "error_handling_incomplete"
```

**Language-Specific Adapters:**
```python
def check_contract_compliance_rust(function_signature, docstring):
    # Check lifetime annotations match usage
    # Verify Result<T, E> types are documented
    # Ensure trait bounds are explained
    pass

def check_contract_compliance_python(function_signature, docstring):
    # Parse type hints from signature
    # Extract types from docstring (e.g., `:param int x:`)
    # Compare for consistency
    pass
```

---

### Lens 2: Runtime Safety

**Generalizes:** [.claude/agents/review-correctness-defensive.md](../.claude/agents/review-correctness-defensive.md)

**Purpose:** Identify potential runtime failures (crashes, panics, exceptions, undefined behavior).

**Checklist:**
```yaml
rubric_items:
  - id: "null_safety"
    question: "Are nullable references checked before dereference?"
    severity_if_violated: "high"
    category: "null_pointer_risk"
    language_patterns:
      rust: "Check for unwrap(), expect() without prior is_some()/is_ok() check"
      python: "Check for dict access without 'get()' or 'in' check"
      go: "Check for nil pointer dereference"
      java: "Check for potential NullPointerException"
    
  - id: "bounds_checking"
    question: "Are array/buffer accesses validated?"
    severity_if_violated: "high"
    category: "bounds_check_missing"
    language_patterns:
      rust: "Check for indexing without bounds validation or use of get()"
      python: "Check for list indexing with user input"
      go: "Check for slice access without length check"
    
  - id: "resource_cleanup"
    question: "Are resources (files, connections, locks) properly released?"
    severity_if_violated: "high"
    category: "resource_leak"
    language_patterns:
      rust: "Prefer RAII types (Drop trait); check manual close()"
      python: "Check for 'with' statements or explicit try/finally"
      go: "Check for defer statements"
      java: "Check for try-with-resources"
    
  - id: "integer_overflow"
    question: "Can arithmetic operations overflow?"
    severity_if_violated: "medium"
    category: "overflow_risk"
    language_patterns:
      rust: "Check for checked_add/checked_mul usage in critical paths"
      python: "Less critical (arbitrary precision ints), but check C extensions"
      go: "Check for overflow in uint operations"
    
  - id: "race_conditions"
    question: "Is shared mutable state properly synchronized?"
    severity_if_violated: "critical"
    category: "race_condition"
    language_patterns:
      rust: "Check for Arc<Mutex<T>> or other sync primitives"
      python: "Check for threading.Lock or multiprocessing synchronization"
      go: "Check for sync.Mutex or channel usage"
```

---

### Lens 3: Maintainability (Structural)

**Generalizes:** [.claude/agents/review-quality-structural.md](../.claude/agents/review-quality-structural.md)

**Purpose:** Assess code structure, readability, and ease of modification.

**Checklist:**
```yaml
rubric_items:
  - id: "function_length"
    question: "Are functions reasonably sized?"
    severity_if_violated: "medium"
    category: "long_function"
    thresholds:
      lines: 50
      cyclomatic_complexity: 10
    language_adjustments:
      rust: "Match expressions can be long; focus on logic branches"
      python: "Decorators and docstrings don't count toward limit"
    
  - id: "nesting_depth"
    question: "Is nesting depth manageable?"
    severity_if_violated: "medium"
    category: "deep_nesting"
    thresholds:
      max_depth: 4
    suggestions:
      - "Use early returns to reduce nesting"
      - "Extract nested blocks into helper functions"
      - "Use guard clauses"
    
  - id: "naming_clarity"
    question: "Are names descriptive and consistent with conventions?"
    severity_if_violated: "low"
    category: "unclear_naming"
    heuristics:
      - "Avoid single-letter names except loop indices"
      - "Avoid vague names (data, info, handle, process)"
      - "Use domain terminology from ticket"
    language_conventions:
      rust: "snake_case for functions/variables, PascalCase for types"
      python: "snake_case for functions/variables, PascalCase for classes"
      go: "camelCase exported, mixedCase unexported"
    
  - id: "duplicate_code"
    question: "Is there duplicated logic that should be extracted?"
    severity_if_violated: "medium"
    category: "duplicate_code"
    threshold: "10+ lines repeated 2+ times"
    
  - id: "error_handling_consistency"
    question: "Is error handling consistent throughout the change?"
    severity_if_violated: "medium"
    category: "inconsistent_error_handling"
    language_patterns:
      rust: "Prefer Result<T, E> over panic; use ? operator"
      python: "Prefer raising exceptions over returning None/-1"
      go: "Always check errors; don't ignore returned 'error' values"
    
  - id: "value_semantics"
    question: "Do domain types use value semantics (immutable, structurally equatable)?"
    severity_if_violated: "medium"
    category: "value_semantics_violation"
    rationale: "CTT (basis.md §IX): types are defined by canonical forms; domain data must be value-semantic"
    language_patterns:
      rust: "Domain structs should derive Clone, PartialEq, Eq; avoid interior mutability (Cell/RefCell) in domain types"
      python: "Domain classes should be frozen dataclasses (@dataclass(frozen=True)) or NamedTuples"
      typescript: "Domain interfaces should be readonly; avoid mutable class fields for data"
      go: "Domain types should be value types (structs), not pointer-heavy"

  - id: "no_mutative_inheritance"
    question: "Are class hierarchies avoided for modeling variants? Are sum types used instead?"
    severity_if_violated: "high"
    category: "mutative_inheritance"
    rationale: "CTT (basis.md §IX): virtual dispatch is non-canonical; sum types are structurally determined"
    language_patterns:
      rust: "Use enum for variants, not trait objects with dyn dispatch (unless at FFI boundary)"
      python: "Use Union[X, Y] or typing.Literal with match/if-isinstance, not subclass hierarchies with method overrides"
      typescript: "Use discriminated unions (type A = {kind: 'x'} | {kind: 'y'}), not class extends chains"
      java: "Use sealed interfaces with record implementations, not abstract class hierarchies"

  - id: "no_mixins"
    question: "Is composition achieved through product types (structs/records), not mixins or multiple inheritance?"
    severity_if_violated: "high"
    category: "mixin_usage"
    rationale: "CTT (basis.md §IX): mixins introduce MRO ambiguity and implicit shared state, violating functionality"
    language_patterns:
      rust: "Not applicable (Rust has no mixins); traits are fine as they are explicit interface contracts"
      python: "Avoid multiple inheritance with method overrides; use composition (has-a) over inheritance (is-a)"
      typescript: "Avoid mixin patterns; compose with explicit object spread or utility types"
```

---

### Lens 4: Maintainability (Evolutionary)

**Generalizes:** [.claude/agents/review-quality-evolutionary.md](../.claude/agents/review-quality-evolutionary.md)

**Purpose:** Assess technical debt and future change impact.

**Checklist:**
```yaml
rubric_items:
  - id: "dependency_coupling"
    question: "Does this change increase coupling between modules?"
    severity_if_violated: "medium"
    category: "tight_coupling"
    heuristics:
      - "New imports from unrelated modules"
      - "Direct access to internal state of other types"
    
  - id: "test_coverage"
    question: "Are new/modified behaviors covered by tests?"
    severity_if_violated: "high"
    category: "missing_tests"
    expectations:
      - "Each new public function has at least 1 test"
      - "Edge cases from specs have explicit tests"
    
  - id: "backward_compatibility"
    question: "Does this change break existing API contracts?"
    severity_if_violated: "critical"
    category: "breaking_change"
    language_specific:
      rust: "Check for removed pub items, changed trait bounds"
      python: "Check for removed/renamed public functions, changed signatures"
    
  - id: "magic_numbers"
    question: "Are literal values explained or extracted as constants?"
    severity_if_violated: "low"
    category: "magic_number"
    exceptions:
      - "0, 1, 2 in common contexts"
      - "Well-known constants (e.g., 404, 500 for HTTP)"
```

---

### Lens 5: Documentation

**Generalizes:** [.claude/agents/review-docs-consistency.md](../.claude/agents/review-docs-consistency.md)

**Purpose:** Verify documentation matches implementation and is complete.

**Checklist:**
```yaml
rubric_items:
  - id: "public_api_docs"
    question: "Do all public APIs have documentation?"
    severity_if_violated: "medium"
    category: "missing_docstring"
    language_requirements:
      rust: "/// doc comments for pub items"
      python: "Docstrings for public functions/classes"
      go: "// comments for exported symbols"
      java: "Javadoc for public methods"
    
  - id: "doc_accuracy"
    question: "Do docs match actual behavior (params, return types, exceptions)?"
    severity_if_violated: "high"
    category: "outdated_docs"
    checks:
      - "Parameter names in docs match function signature"
      - "Return type in docs matches actual type"
      - "Documented exceptions are actually raised"
    
  - id: "usage_examples"
    question: "Do complex APIs have usage examples?"
    severity_if_violated: "low"
    category: "missing_examples"
    threshold: "Functions with 3+ parameters or non-trivial types"
    
  - id: "readme_updates"
    question: "If public API changed, is README/user-facing docs updated?"
    severity_if_violated: "medium"
    category: "stale_user_docs"
    trigger: "Changes to files listed in profile.layout.doc_paths"
```

---

### Lens 6: Error Surface

**Generalizes:** [.claude/agents/review-error-surface.md](../agents/review-error-surface.md)

**Purpose:** Identify incomplete error handling, swallowed errors, and unclear error messages.

**Checklist:**
```yaml
rubric_items:
  - id: "broad_catch"
    question: "Are catch/except clauses scoped to the specific errors expected?"
    severity_if_violated: "high"
    category: "broad_catch"
    language_patterns:
      rust: "Avoid catch-all with Box<dyn Error> at internal boundaries"
      python: "Avoid bare except or except Exception without re-raise"
      go: "Not applicable (Go returns errors explicitly)"
      typescript: "Avoid catch(e) {} with no handling"

  - id: "error_chain"
    question: "Do re-raised errors preserve the original cause?"
    severity_if_violated: "high"
    category: "missing_traceback"
    language_patterns:
      rust: "Use .context() or From trait to wrap errors"
      python: "Use raise X from e to preserve traceback"
      go: "Use fmt.Errorf('context: %w', err) for wrapping"
      typescript: "Use new Error('msg', {cause: originalError})"

  - id: "error_message_quality"
    question: "Do error messages include context (parameter name, value, expected range)?"
    severity_if_violated: "medium"
    category: "bare_error_message"

  - id: "error_boundary"
    question: "Is error handling at the effect boundary, not inside pure business logic?"
    severity_if_violated: "medium"
    category: "error_at_wrong_boundary"
```

---

### Lens 7: Operations Hygiene

**Generalizes:** [.claude/agents/review-operations-hygiene.md](../agents/review-operations-hygiene.md)

**Purpose:** Assess logging consistency, configuration management, and magic constant usage.

**Checklist:**
```yaml
rubric_items:
  - id: "logging_consistency"
    question: "Are similar events logged at the same level?"
    severity_if_violated: "medium"
    category: "inconsistent_logging"

  - id: "no_bare_print"
    question: "Are print/println/console.log statements replaced with structured logging?"
    severity_if_violated: "low"
    category: "bare_print"
    language_patterns:
      rust: "Use tracing or log crate, not println!"
      python: "Use logging module, not print()"
      go: "Use slog or log/slog, not fmt.Println"
      typescript: "Use structured logger, not console.log"

  - id: "no_hardcoded_config"
    question: "Are configuration values (URLs, ports, timeouts) read from config/env?"
    severity_if_violated: "medium"
    category: "hardcoded_config"

  - id: "named_constants"
    question: "Are numeric and string literals explained via named constants?"
    severity_if_violated: "low"
    category: "magic_number"
    exceptions:
      - "0, 1, -1 in common contexts"
      - "Well-known constants (HTTP 404/500)"
      - "Test fixtures and enum definitions"
```

---

### Lens 8: Test Quality

**Generalizes:** [.claude/agents/review-test-quality.md](../agents/review-test-quality.md)

**Purpose:** Evaluate whether tests verify behavior effectively and are well-structured.

**Checklist:**
```yaml
rubric_items:
  - id: "no_tautological_tests"
    question: "Does each test assert something meaningful (not just that a mock returns its config)?"
    severity_if_violated: "high"
    category: "tautological_test"

  - id: "assertion_strength"
    question: "Are assertions specific enough to catch regressions?"
    severity_if_violated: "medium"
    category: "weak_assertion"
    heuristics:
      - "Prefer exact value checks over truthiness checks"
      - "Prefer structural equality over reference identity"

  - id: "mock_scope"
    question: "Is the amount of mocking proportional — enough to isolate, not so much that nothing real is tested?"
    severity_if_violated: "medium"
    category: "over_mocking"

  - id: "behavior_not_implementation"
    question: "Do tests verify observable behavior, not internal method calls or private state?"
    severity_if_violated: "medium"
    category: "implementation_detail_test"

  - id: "test_coverage_for_new_code"
    question: "Does new feature code have corresponding test coverage?"
    severity_if_violated: "high"
    category: "missing_tests"
```

---

### Lens 9: FFI Boundary Safety, Moldable DX, and Hot-Reload

**Purpose:** Verify that components crossing language boundaries follow safe FFI practices, provide moldable developer experience artifacts, and support safe hot-reload operations.

**Generalizes:** forge.md §7, §14 checklists

**When active:** FFI checklist items always apply when reviewing code with FFI boundaries. Moldable DX items apply when `extensions.moldable.enabled: true`. Hot-reload items apply when `extensions.hot_reload.enabled: true`.

**FFI Boundary Safety Checklist** (7 items, from forge.md §7.3):
```yaml
rubric_items:
  - id: opaque_handles
    question: "Are all Rust types exposed as opaque handles (not struct layouts)?"
    severity_if_violated: high
    category: ffi_safety
  - id: no_borrowed_lifetimes
    question: "Do any borrowed references or lifetimes cross the FFI boundary?"
    severity_if_violated: critical
    category: ffi_safety
  - id: errors_as_data
    question: "Do all FFI calls return Result-style error objects instead of panicking?"
    severity_if_violated: high
    category: ffi_safety
  - id: interface_versioned
    question: "Does every exported interface have an interface_hash and semver?"
    severity_if_violated: medium
    category: ffi_safety
  - id: conformance_tests
    question: "Do round-trip conformance tests exist for each exported function?"
    severity_if_violated: medium
    category: ffi_safety
  - id: ownership_explicit
    question: "Are ownership rules explicit with destructor functions for opaque handles?"
    severity_if_violated: high
    category: ffi_safety
  - id: concurrency_explicit
    question: "Is the concurrency model explicit — are boundary calls thread-safe or single-threaded by construction?"
    severity_if_violated: high
    category: ffi_safety
```

**Moldable DX Checklist** (5 items, from forge.md §14):
```yaml
rubric_items:
  - id: example_objects
    question: "Does every component ship at least one Example Object?"
    severity_if_violated: low
    category: moldable_dx
  - id: inspectable_live_objects
    question: "Can the workbench inspect example outputs as live objects?"
    severity_if_violated: low
    category: moldable_dx
  - id: cheap_custom_tools
    question: "Are custom views/actions low-ceremony to add?"
    severity_if_violated: info
    category: moldable_dx
  - id: promote_to_tool
    question: "Can throwaway analysis tools be promoted to permanent tools?"
    severity_if_violated: info
    category: moldable_dx
  - id: narrative_capture
    question: "Can investigations be captured as shareable narratives?"
    severity_if_violated: info
    category: moldable_dx
```

**Hot-Reload Checklist** (5 items, from forge.md §14):
```yaml
rubric_items:
  - id: quiescence_point
    question: "Does reload happen at a quiescence point?"
    severity_if_violated: high
    category: hot_reload
  - id: snapshot_versioned
    question: "Is snapshot/restore implemented with a versioned schema?"
    severity_if_violated: high
    category: hot_reload
  - id: migration_function
    question: "Do schema changes have a migration function or blocked guidance?"
    severity_if_violated: medium
    category: hot_reload
  - id: smoke_after_reload
    question: "Do smoke examples run after reload?"
    severity_if_violated: medium
    category: hot_reload
  - id: trace_generations
    question: "Does observability link old/new generations in traces?"
    severity_if_violated: low
    category: hot_reload
```

**Cross-references:** workflow-contract.md §II.5, moldable-canvas.md, hot-reload.md, component-model.md

---

## IV. Parameterization by Project Profile

Review prompts are instantiated with profile tokens:

```python
def generate_review_prompt(agent_config, diff, ticket, profile):
    template = load_template(agent_config.prompt_template)
    
    context = {
        "AGENT_NAME": agent_config.id,
        "LENS": agent_config.lens,
        "PROJECT_NAME": profile.identity.project_name,
        "LANGUAGE": profile.identity.language,
        "MODEL": agent_config.model,
        "DIFF": diff,
        "TICKET_DESCRIPTION": ticket.description,
        "ACCEPTANCE_CRITERIA": format_acs(ticket.acceptance_criteria),
        "TEST_OUTPUT_FORMAT": profile.toolchain.test_output_format,
        "LINT_CMD": profile.toolchain.lint_cmd,
        "DOC_STYLE": profile.extensions.language_specific.get(profile.identity.language.lower(), {}).get("doc_style", "standard"),
        "RUBRIC_ITEMS": generate_rubric_items(agent_config.lens, profile)
    }
    
    return template.render(context)
```

---

## V. Language-Specific Heuristics Plugin System

For checks that vary by language, use **plugin architecture**:

```python
class LanguageHeuristics:
    def check_null_safety(self, code_snippet: str) -> List[Issue]:
        raise NotImplementedError

class RustHeuristics(LanguageHeuristics):
    def check_null_safety(self, code_snippet: str) -> List[Issue]:
        issues = []
        # Look for .unwrap() or .expect() without prior checks
        if re.search(r'\.unwrap\(\)', code_snippet):
            if not re.search(r'\.is_some\(\)|\.is_ok\(\)', code_snippet):
                issues.append(Issue(
                    category="null_pointer_risk",
                    message="unwrap() without is_some()/is_ok() check",
                    severity="high"
                ))
        return issues

class PythonHeuristics(LanguageHeuristics):
    def check_null_safety(self, code_snippet: str) -> List[Issue]:
        issues = []
        # Look for dict access without get() or 'in' check
        if re.search(r'\[\w+\]', code_snippet):
            if not re.search(r'\.get\(|if \w+ in ', code_snippet):
                issues.append(Issue(
                    category="null_pointer_risk",
                    message="Dictionary key access without 'get()' or 'in' check",
                    severity="medium"
                ))
        return issues

# Factory
def get_heuristics(language: str) -> LanguageHeuristics:
    registry = {
        "rust": RustHeuristics,
        "python": PythonHeuristics,
        # ... add more languages
    }
    return registry.get(language.lower(), GenericHeuristics)()
```

---

## VI. Example: Instantiated Review Prompt for Rust

**Input:**
- Lens: `runtime_safety`
- Language: `Rust`
- Diff: (changes to `src/http/retry.rs`)

**Generated Prompt:**
```markdown
# Runtime Safety Review: Rust Project

**Project:** oxide-vm (Rust)  
**Model:** claude-sonnet-4  
**Lens:** runtime_safety

---

## Context

You are reviewing code changes for a Rust project. Your focus is **runtime_safety**.

**Changes:**
```diff
+fn calculate_backoff(attempt: u32, base_delay: u64) -> u64 {
+    let mut delay = base_delay;
+    for _ in 0..attempt {
+        delay = delay * 2;  // Potential overflow
+    }
+    delay
+}
```

**Ticket:** FEAT-123: Add exponential backoff with jitter
**Acceptance Criteria:**
- Exponential backoff with multiplier 2.0
- Jitter to prevent thundering herd
- Cap maximum delay at 60 seconds

---

## Rust-Specific Safety Checks

### 1. Null Safety
- ✅ Check for `.unwrap()` or `.expect()` without prior validation
- ✅ Look for unsafe pointer dereference

### 2. Bounds Checking
- ✅ Array indexing without bounds validation
- ✅ Prefer `.get()` over `[]` for dynamic indices

### 3. Resource Cleanup
- ✅ Resources use RAII types (implement Drop)
- ✅ Manual cleanup uses proper error handling

### 4. Integer Overflow
- ⚠️ **ISSUE FOUND**: Unchecked multiplication in loop
- Recommend: Use `checked_mul()` or `saturating_mul()`

### 5. Race Conditions
- N/A: No concurrent access in this change

---

## Findings

```json
[
  {
    "schema_version": "finding.v1",
    "id": "FIND-A3F2B8C1",
    "agent_id": "correctness_defensive",
    "model": "claude-sonnet-4",
    "lens": "runtime_safety",
    "severity": "high",
    "category": "overflow_risk",
    "message": "Unchecked integer multiplication can overflow for large attempt values",
    "location": {
      "file": "src/http/retry.rs",
      "line": 87,
      "symbol": "calculate_backoff"
    },
    "evidence": {
      "snippet": "delay = delay * 2;",
      "explanation": "For attempt=32, base_delay=1000, result would be 4.29 billion. u64 max is 18 quintillion so overflow unlikely, but for larger base_delay or uncapped attempts, this could wrap."
    },
    "confidence": 0.85,
    "suggested_fix": {
      "description": "Use saturating_mul to cap at u64::MAX instead of wrapping",
      "patch": {
        "type": "replace",
        "old_text": "delay = delay * 2;",
        "new_text": "delay = delay.saturating_mul(2);",
        "line": 87
      },
      "auto_fixable": true,
      "risk": "low"
    }
  }
]
```
```

---

## VII. Migration Path for Existing Agents

1. **Extract Rubric**: Identify language-agnostic checklist items from existing prompt
2. **Identify Language Assumptions**: List hardcoded Python/SDK references
3. **Parameterize**: Replace with `{{TOKENS}}` from profile
4. **Plugin Heuristics**: Move language-specific checks to heuristics plugins
5. **Test Instantiation**: Generate prompts for 2+ languages, verify they make sense
6. **Validate Output**: Ensure findings conform to `finding.v1` schema

**Example Conversion:**

**Before (Python-specific):**
```markdown
## Check for Missing Docstrings
Review each added `def` or `class` for docstring presence. In Python, all public APIs should have Google-style docstrings.
```

**After (Generic):**
```markdown
## Public API Documentation
Review each added {{FUNCTION_KEYWORD}} or {{CLASS_KEYWORD}} for documentation presence. 
In {{LANGUAGE}}, all public APIs should have {{DOC_STYLE}} documentation.

{{#if LANGUAGE == "Python"}}
- Check for triple-quoted docstrings under function def
- Verify Google-style or NumPy-style format
{{/if}}

{{#if LANGUAGE == "Rust"}}
- Check for /// doc comments above pub fn or pub struct
- Verify examples use ```no_run or ```ignore if non-runnable
{{/if}}
```

---

This rubric system ensures reviews are **consistent**, **language-agnostic**, and **produce standardized findings** for any project $L$.
