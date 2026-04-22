---
description: "Standard finding output format for all review agents. Ensures severity levels, categories, locations, and suggested fixes are compatible across agents."
alwaysApply: true
---

# Finding Schema (v1)

All review agents MUST produce findings conforming to this schema.

## Finding Structure

```json
{
  "schema_version": "finding.v1",
  "id": "<content-hash>",
  "agent_id": "<agent name>",
  "severity": "critical | high | medium | low | info",
  "category": "<from taxonomy below>",
  "message": "<clear description>",
  "location": {
    "file": "relative/path/to/file",
    "line_start": 42,
    "line_end": 55,
    "symbol": "<function or type name>"
  },
  "evidence": {
    "snippet": "<relevant code>",
    "explanation": "<why this is an issue>"
  },
  "confidence": 0.85,
  "suggested_fix": {
    "description": "<what to change>",
    "auto_fixable": true,
    "risk": "low | medium | high",
    "patch": {
      "type": "replace",
      "old_text": "<original>",
      "new_text": "<replacement>",
      "line": 42
    }
  }
}
```

## Severity Levels

| Level | Meaning | Action |
|-------|---------|--------|
| **critical** | Will cause crash, data loss, or security vulnerability | Block merge, fix immediately |
| **high** | Likely bug or contract violation | Block merge, fix before review |
| **medium** | Code quality issue, potential future bug | Advisory, fix recommended |
| **low** | Style, naming, minor improvement | Advisory, fix optional |
| **info** | Observation, no action needed | Informational only |

## Category Taxonomy

### Correctness
- `null_pointer_risk` — Dereference of nullable without check
- `bounds_check_missing` — Array/buffer access without validation
- `overflow_risk` — Unchecked arithmetic
- `race_condition` — Shared mutable state without sync
- `resource_leak` — File/connection/lock not released
- `spec_violation` — Implementation doesn't match specification
- `contract_violation` — Function signature disagrees with behavior
- `edge_case_missing` — Specified edge case not handled
- `error_handling_incomplete` — Error paths not covered

### Quality
- `long_function` — Function exceeds length/complexity threshold
- `deep_nesting` — Nesting depth > 4 levels
- `unclear_naming` — Names are misleading or too vague
- `duplicate_code` — 10+ lines repeated 2+ times
- `inconsistent_error_handling` — Mixed error patterns
- `tight_coupling` — Inappropriate dependency between modules
- `missing_tests` — New behavior without test coverage
- `breaking_change` — API change without migration
- `magic_number` — Unexplained literal value

### Paradigmatic (from basis.md §IX)
- `value_semantics_violation` — Domain type uses mutable state instead of value semantics
- `mutative_inheritance` — Class hierarchy with virtual dispatch for variant modeling
- `mixin_usage` — Multiple inheritance or mixin composition with shared mutable state
- `reference_identity` — Equality check uses reference identity instead of structural comparison
- `implicit_mutation` — State change through hidden side effect, not explicit effect

### Error Surface
- `broad_catch` — Overly broad exception catch that swallows unrelated errors
- `missing_traceback` — Re-raised exception loses original traceback or error chain
- `bare_error_message` — Exception message lacks context or actionable hints
- `error_at_wrong_boundary` — try/catch in pure business logic instead of at effect boundary

### Operations
- `inconsistent_logging` — Similar events logged at different levels
- `hardcoded_config` — Configuration value that should come from env/config
- `bare_print` — Print statement that should use a logger

### Test Quality
- `tautological_test` — Test that always passes regardless of behavior
- `weak_assertion` — Assertion too broad to catch regressions
- `over_mocking` — So much is mocked that the test validates nothing real
- `fixture_misuse` — Fixture does too much or test-local setup should be a fixture
- `implementation_detail_test` — Test verifies internal method calls rather than observable behavior

### Documentation
- `missing_docstring` — Public API without documentation
- `outdated_docs` — Documentation doesn't match code
- `stale_user_docs` — README/guide has incorrect information
- `missing_examples` — Complex API without usage examples

## Deduplication

When multiple agents flag the same location:
- Keep the finding with highest severity
- Merge evidence from all agents
- Note which agents flagged it (for confidence scoring)
