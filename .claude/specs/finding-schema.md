# Common Finding Schema: Universal Review Output Format

This specification defines the **standard finding format** emitted by all review agents, ensuring consistency across languages, models, and lenses. It provides deterministic deduplication and triage capabilities for the [phase orchestrator](./phase-orchestrator.md).

---

## I. Overview

A **finding** is a structured observation from a review agent indicating a potential issue, improvement, or compliance check result. All review agents (correctness, quality, docs, etc.) emit findings conforming to this schema.

**Key Properties:**
- **Language-Agnostic**: Fields do not assume specific language constructs
- **Deterministic**: Identical findings from different agents can be deduplicated
- **Actionable**: Contains enough context for automated or manual remediation
- **Versioned**: Schema version allows evolution over time

---

## II. Finding Schema (JSON Schema)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["schema_version", "id", "agent_id", "severity", "category", "message", "location"],
  "properties": {
    "schema_version": {
      "type": "string",
      "const": "finding.v1",
      "description": "Schema version for compatibility checks"
    },
    "id": {
      "type": "string",
      "pattern": "^FIND-[A-Z0-9]{8}$",
      "description": "Unique finding identifier (e.g., FIND-A3F2B8C1)"
    },
    "agent_id": {
      "type": "string",
      "description": "Identifier of the agent that generated this finding (from review_graph)"
    },
    "model": {
      "type": "string",
      "description": "Model used by agent (e.g., 'claude-sonnet-4', 'gpt-4')"
    },
    "lens": {
      "type": "string",
      "enum": ["specification_adherence", "runtime_safety", "maintainability", "documentation", "performance", "security"],
      "description": "Review perspective/focus area"
    },
    "severity": {
      "type": "string",
      "enum": ["critical", "high", "medium", "low", "info"],
      "description": "Impact level of the finding"
    },
    "category": {
      "type": "string",
      "description": "Specific issue type (e.g., 'null_pointer_risk', 'unclear_naming', 'missing_docs')"
    },
    "message": {
      "type": "string",
      "minLength": 10,
      "description": "Human-readable description of the issue"
    },
    "location": {
      "type": "object",
      "required": ["file"],
      "properties": {
        "file": {"type": "string"},
        "line": {"type": "integer", "minimum": 1},
        "end_line": {"type": "integer", "minimum": 1},
        "column": {"type": "integer", "minimum": 1},
        "end_column": {"type": "integer", "minimum": 1},
        "symbol": {"type": "string", "description": "Function/class/variable name"}
      }
    },
    "evidence": {
      "type": "object",
      "properties": {
        "snippet": {"type": "string", "description": "Code excerpt demonstrating the issue"},
        "context": {"type": "string", "description": "Surrounding code for context"},
        "explanation": {"type": "string", "description": "Why this is an issue"}
      }
    },
    "confidence": {
      "type": "number",
      "minimum": 0.0,
      "maximum": 1.0,
      "description": "Agent's confidence in this finding (0.0 = uncertain, 1.0 = certain)"
    },
    "suggested_fix": {
      "type": "object",
      "properties": {
        "description": {"type": "string"},
        "patch": {
          "type": "object",
          "properties": {
            "type": {"type": "string", "enum": ["replace", "insert", "delete"]},
            "old_text": {"type": "string"},
            "new_text": {"type": "string"},
            "line": {"type": "integer"}
          }
        },
        "auto_fixable": {"type": "boolean"},
        "risk": {"type": "string", "enum": ["low", "medium", "high"]}
      }
    },
    "metadata": {
      "type": "object",
      "description": "Additional agent-specific data"
    },
    "references": {
      "type": "array",
      "items": {"type": "string"},
      "description": "Links to docs, specs, or related tickets"
    },
    "timestamp": {
      "type": "string",
      "format": "date-time",
      "description": "When finding was generated"
    }
  }
}
```

---

## III. Field Definitions

### Core Identification

**`id` (string, required)**
- Unique identifier for this finding
- Format: `FIND-{8 hex chars}` (e.g., `FIND-A3F2B8C1`)
- Generated deterministically from content hash (for deduplication)

**`agent_id` (string, required)**
- Which agent produced this finding
- Maps to `profile.review_graph.agents[].id`
- Examples: `"correctness_spec"`, `"quality_structural"`, `"docs_consistency"`

**`model` (string, optional)**
- LLM model used by the agent
- Examples: `"claude-sonnet-4"`, `"gpt-4"`, `"claude-opus"`

**`lens` (enum, optional)**
- High-level category of review focus
- Values: `specification_adherence`, `runtime_safety`, `maintainability`, `documentation`, `performance`, `security`

---

### Severity & Classification

**`severity` (enum, required)**
- Impact level of the issue
- **`critical`**: Blocks merge; must fix before proceeding (e.g., security vulnerability, data loss risk)
- **`high`**: Should fix; significant defect (e.g., spec violation, likely runtime error)
- **`medium`**: Should address; quality/maintainability concern (e.g., code smell, unclear naming)
- **`low`**: Nice to fix; minor polish (e.g., formatting inconsistency, trivial optimization)
- **`info`**: FYI; not a problem (e.g., "This pattern is uncommon but valid")

**`category` (string, required)**
- Specific issue type for programmatic filtering
- Examples:
  - Correctness: `null_pointer_risk`, `bounds_check_missing`, `race_condition`, `spec_violation`
  - Quality: `deep_nesting`, `long_function`, `duplicate_code`, `unclear_naming`
  - Docs: `missing_docstring`, `outdated_docs`, `inconsistent_api_docs`
  - Performance: `inefficient_algorithm`, `unnecessary_allocation`

---

### Location

**`location` (object, required)**
- Where in the codebase the issue exists
- **`file`** (string, required): Relative path from project root
- **`line`** (int, optional): Starting line number (1-indexed)
- **`end_line`** (int, optional): Ending line number for multi-line issues
- **`column`** / **`end_column`** (int, optional): Column positions
- **`symbol`** (string, optional): Function/class/variable name

**Examples:**
```json
{"file": "src/http/retry.rs", "line": 87, "symbol": "calculate_backoff"}
{"file": "tests/retry_tests.rs", "line": 42, "end_line": 48}
{"file": "README.md", "line": 15}
```

---

### Evidence

**`evidence` (object, optional)**
- Supporting information for the finding
- **`snippet`**: Code excerpt showing the issue (5-10 lines typical)
- **`context`**: Broader surrounding code (10-20 lines)
- **`explanation`**: Human explanation of why this is a problem

**Example:**
```json
{
  "snippet": "delay = delay * 2  // Line 87",
  "context": "fn calculate_backoff(attempt: u32, base_delay: u64) -> u64 {\n    let delay = base_delay;\n    for _ in 0..attempt {\n        delay = delay * 2;  // Issue here\n    }\n    delay\n}",
  "explanation": "Integer multiplication can overflow for large attempt counts. Consider using checked_mul() or capping the max delay."
}
```

---

### Confidence & Fix Suggestions

**`confidence` (float, optional)**
- Agent's certainty about this finding (0.0 - 1.0)
- Used for auto-fix eligibility and prioritization
- **0.9-1.0**: Very confident (likely true positive)
- **0.7-0.9**: Confident (probably correct)
- **0.5-0.7**: Uncertain (may need human review)
- **< 0.5**: Speculative (low priority)

**`suggested_fix` (object, optional)**
- Concrete remediation proposal
- **`description`**: Human explanation of the fix
- **`patch`**: Machine-applicable change
- **`auto_fixable`**: Whether fix can be applied automatically
- **`risk`**: Risk level of applying the fix (for gating)

**Example:**
```json
{
  "suggested_fix": {
    "description": "Use checked_mul to prevent overflow",
    "patch": {
      "type": "replace",
      "old_text": "delay = delay * 2;",
      "new_text": "delay = delay.checked_mul(2).unwrap_or(u64::MAX);",
      "line": 87
    },
    "auto_fixable": true,
    "risk": "low"
  }
}
```

---

### Metadata & References

**`metadata` (object, optional)**
- Agent-specific additional data
- Not used for deduplication or triage
- Examples: `{"reasoning_tokens": 1523}`, `{"related_findings": ["FIND-XYZ"]}`

**`references` (array of strings, optional)**
- Links to relevant documentation, specs, or tickets
- Examples: `["https://rust-lang.org/docs/overflow", "SPEC-042"]`

---

## IV. Deduplication Strategy

Identical issues found by multiple agents should merge into a single finding.

### Deduplication Key

Generate a stable hash from:
```python
def dedupe_key(finding: Finding) -> str:
    canonical = {
        "file": finding.location.file,
        "line": finding.location.line or 0,
        "category": finding.category,
        "message": normalize_whitespace(finding.message)
    }
    return hashlib.sha256(json.dumps(canonical, sort_keys=True).encode()).hexdigest()[:8]
```

### Merge Strategy

When two findings have the same dedupe key:

```python
def merge_findings(f1: Finding, f2: Finding) -> Finding:
    return Finding(
        id=f1.id,  # Keep first ID
        agent_id=f"{f1.agent_id}+{f2.agent_id}",  # Combine agents
        severity=max(f1.severity, f2.severity),   # Most severe
        confidence=max(f1.confidence, f2.confidence),  # Most confident
        message=f1.message,  # Keep first message (or merge with template)
        suggested_fix=f1.suggested_fix or f2.suggested_fix,  # Prefer non-null
        evidence={
            "snippet": f1.evidence.snippet,
            "sources": [f1.agent_id, f2.agent_id]
        }
    )
```

**Configurable via:**
```yaml
review_graph:
  merge_strategy: "deduplicate_by_location"  # or "keep_all", "highest_confidence"
```

---

## V. Severity Escalation Rules

Some categories automatically map to severity:

```yaml
category_severity_mapping:
  # Critical (always block)
  - {category: "security_vulnerability", severity: "critical"}
  - {category: "data_loss_risk", severity: "critical"}
  - {category: "memory_safety_violation", severity: "critical"}
  
  # High (likely block based on profile)
  - {category: "spec_violation", severity: "high"}
  - {category: "null_pointer_risk", severity: "high"}
  - {category: "race_condition", severity: "high"}
  
  # Medium (warn, may require user decision)
  - {category: "deep_nesting", severity: "medium"}
  - {category: "missing_error_handling", severity: "medium"}
  
  # Low (log only)
  - {category: "style_inconsistency", severity: "low"}
  - {category: "unused_variable", severity: "low"}
```

Agents MAY override if context justifies (e.g., unused variable in dead code path → info).

---

## VI. Language-Agnostic Category Taxonomy

### Correctness

| Category | Description | Example |
|----------|-------------|---------|
| `spec_violation` | Behavior doesn't match documented requirements | Function returns `null` but spec says it never does |
| `null_pointer_risk` | Potential null/nil/None dereference | Accessing field without null check |
| `bounds_check_missing` | Array/buffer access without validation | `arr[idx]` where `idx` is user input |
| `race_condition` | Concurrent access without synchronization | Shared mutable state in multi-threaded code |
| `resource_leak` | Not releasing resources (files, connections) | Open file without close/finally |
| `logic_error` | Algorithm doesn't implement intended behavior | Off-by-one in loop condition |

### Quality / Maintainability

| Category | Description | Example |
|----------|-------------|---------|
| `deep_nesting` | Excessive indentation levels | 5+ levels of nested if/for |
| `long_function` | Function exceeds complexity threshold | 100+ lines, 15+ branches |
| `duplicate_code` | Repeated logic should be extracted | Same 10-line block in 3 places |
| `unclear_naming` | Variables/functions poorly named | `x`, `data`, `doStuff()` |
| `magic_number` | Unexplained literal values | `if count > 42` (why 42?) |
| `god_class` | Class with too many responsibilities | 50+ methods, 1000+ lines |

### Paradigmatic (from basis.md §IX)

| Category | Description | Example |
|----------|-------------|---------|
| `value_semantics_violation` | Domain type uses mutable state instead of value semantics | Mutable class fields on a domain model; non-frozen dataclass |
| `mutative_inheritance` | Class hierarchy with virtual dispatch used for variant modeling | Subclass overrides base method to change behavior; `instanceof` dispatch chain |
| `mixin_usage` | Multiple inheritance or mixin composition with shared mutable state | Python class inheriting from multiple mixins that share `self` fields |
| `reference_identity` | Equality check uses reference identity instead of structural comparison | Using `is` (Python) or `===` on objects (JS) instead of value equality |
| `implicit_mutation` | State change through hidden side effect, not explicit effect | Setter method that silently mutates shared state; method with no return that changes `self` |

### Documentation

| Category | Description | Example |
|----------|-------------|---------|
| `missing_docstring` | Public API lacks documentation | Exported function without doc comment |
| `outdated_docs` | Docs don't match current behavior | Docstring says returns `int`, actually returns `str` |
| `inconsistent_api_docs` | Similar functions documented differently | Some have examples, others don't |
| `missing_examples` | Complex API lacks usage examples | 10-parameter function without example call |

### Performance

| Category | Description | Example |
|----------|-------------|---------|
| `inefficient_algorithm` | Suboptimal complexity | O(n²) when O(n log n) available |
| `unnecessary_allocation` | Allocating memory that could be reused | Creating list in loop instead of reusing |
| `blocking_io_in_loop` | Synchronous I/O in hot path | Database query inside tight loop |

### Security

| Category | Description | Example |
|----------|-------------|---------|
| `security_vulnerability` | Known security issue (injection, XSS) | SQL query with string concatenation |
| `hardcoded_secret` | Credentials in source code | `password = "admin123"` |
| `insecure_random` | Weak RNG for security-sensitive use | Using `rand()` for crypto keys |

---

## VII. Example Findings

### Example 1: Correctness (High Severity)

```json
{
  "schema_version": "finding.v1",
  "id": "FIND-A3F2B8C1",
  "agent_id": "correctness_spec",
  "model": "claude-sonnet-4",
  "lens": "specification_adherence",
  "severity": "high",
  "category": "spec_violation",
  "message": "Function does not handle empty retry list as specified in acceptance criteria #3",
  "location": {
    "file": "src/http/client.rs",
    "line": 145,
    "symbol": "execute_with_retries"
  },
  "evidence": {
    "snippet": "fn execute_with_retries(retries: Vec<Duration>) -> Result<Response> {\n    for delay in retries {\n        // ...\n    }\n    Err(\"max retries exceeded\")  // What if retries is empty?\n}",
    "explanation": "AC #3 states: 'If retry list is empty, execute once without delay.' Current code would return error immediately."
  },
  "confidence": 0.9,
  "suggested_fix": {
    "description": "Add check for empty retry list",
    "patch": {
      "type": "insert",
      "new_text": "if retries.is_empty() {\n    return self.execute_once();\n}\n",
      "line": 146
    },
    "auto_fixable": true,
    "risk": "low"
  },
  "references": ["FEAT-123#acceptance_criteria"],
  "timestamp": "2026-02-15T15:30:00Z"
}
```

### Example 2: Quality (Medium Severity)

```json
{
  "schema_version": "finding.v1",
  "id": "FIND-B7E4C2D9",
  "agent_id": "quality_structural",
  "model": "claude-sonnet-4",
  "lens": "maintainability",
  "severity": "medium",
  "category": "deep_nesting",
  "message": "Function has 5 levels of nesting, consider extracting inner logic",
  "location": {
    "file": "src/http/retry.rs",
    "line": 87,
    "end_line": 112,
    "symbol": "calculate_backoff"
  },
  "evidence": {
    "snippet": "if condition1 {\n    if condition2 {\n        for item in list {\n            if condition3 {\n                match result {\n                    // ...\n                }\n            }\n        }\n    }\n}",
    "explanation": "Deep nesting reduces readability and makes testing difficult. Consider early returns or extracting helper functions."
  },
  "confidence": 0.85,
  "suggested_fix": {
    "description": "Extract inner loop into separate function",
    "auto_fixable": false,
    "risk": "low"
  },
  "timestamp": "2026-02-15T15:32:00Z"
}
```

### Example 3: Documentation (Low Severity)

```json
{
  "schema_version": "finding.v1",
  "id": "FIND-C5A8D3F1",
  "agent_id": "docs_consistency",
  "model": "claude-sonnet-4",
  "lens": "documentation",
  "severity": "low",
  "category": "missing_examples",
  "message": "Public API function lacks usage example",
  "location": {
    "file": "src/http/client.rs",
    "line": 45,
    "symbol": "with_retry_policy"
  },
  "evidence": {
    "explanation": "Function has 5 parameters with complex types; an example would help users understand correct usage."
  },
  "confidence": 0.7,
  "suggested_fix": {
    "description": "Add doc comment with example",
    "patch": {
      "type": "insert",
      "new_text": "/// # Example\n/// ```\n/// let client = HttpClient::new()\n///     .with_retry_policy(RetryPolicy::exponential(3, Duration::from_secs(1)));\n/// ```\n",
      "line": 44
    },
    "auto_fixable": true,
    "risk": "low"
  },
  "timestamp": "2026-02-15T15:35:00Z"
}
```

---

## VIII. Integration with Phase Orchestrator

The [phase orchestrator](./phase-orchestrator.md) collects findings from all agents and applies governance rules:

```python
def process_review_findings(findings: List[Finding], profile: ProjectProfile) -> ReviewResult:
    # Deduplicate
    unique = deduplicate_findings(findings, strategy=profile.review_graph.merge_strategy)
    
    # Filter by severity threshold
    blocking = [f for f in unique if f.severity in ["critical", "high"]]
    
    # Apply auto-fix rules
    auto_fix_candidates = []
    for finding in unique:
        if finding.suggested_fix and finding.suggested_fix.auto_fixable:
            decision = apply_autofix_rules(finding, profile.governance.autofix_confidence_rules)
            if decision == "apply_automatically":
                auto_fix_candidates.append(finding)
    
    return ReviewResult(
        status="blocked" if blocking else "success",
        findings=unique,
        blocking_findings=blocking,
        auto_fix_candidates=auto_fix_candidates
    )
```

---

This schema ensures findings are **structured**, **actionable**, and **language-agnostic**, enabling deterministic triage and remediation across any project $L$.
