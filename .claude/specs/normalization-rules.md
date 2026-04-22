# Normalization Rules: Deterministic Artifact Processing

This specification defines **normalization rules** that ensure workflow artifacts are deterministic, stable, and suitable for ingestion by the external code generation pipeline. These rules enforce consistency across runs, models, and projects.

---

## I. Overview

**Normalization** transforms artifacts into a canonical form where:
- **Byte-stable**: Identical inputs produce byte-identical outputs
- **Order-independent**: Processing order doesn't affect final representation
- **Timestamp-isolated**: Time-of-generation doesn't affect content hashes
- **Whitespace-normalized**: Consistent formatting regardless of source

All artifacts conforming to [artifact-contracts.md](./artifact-contracts.md) MUST be normalized before pipeline ingestion.

---

## II. JSON Normalization Rules

### Rule 1: Lexicographic Key Ordering

All JSON objects MUST have keys sorted alphabetically (case-sensitive, ASCII order).

**Before:**
```json
{
  "ticket_id": "FEAT-123",
  "schema_version": "test_run.v1",
  "status": "success"
}
```

**After:**
```json
{
  "schema_version": "test_run.v1",
  "status": "success",
  "ticket_id": "FEAT-123"
}
```

**Implementation:**
```python
import json

def normalize_json(obj):
    return json.dumps(obj, sort_keys=True, indent=2, ensure_ascii=False)
```

---

### Rule 2: Explicit Null Values

Optional fields that are null MUST be included explicitly (not omitted).

**Before:**
```json
{
  "ticket_id": "FEAT-123",
  "blocked_reason": null  // Omitted in some serializers
}
```

**After:**
```json
{
  "blocked_reason": null,
  "ticket_id": "FEAT-123"
}
```

**Rationale:** Ensures schema completeness and diff stability.

---

### Rule 3: Canonical Whitespace

- **Indentation:** 2 spaces (no tabs)
- **Line endings:** LF (`\n`) only, not CRLF (`\r\n`)
- **Trailing whitespace:** None
- **Final newline:** Present

**Implementation:**
```python
def normalize_whitespace(content: str) -> str:
    # Convert CRLF to LF
    content = content.replace('\r\n', '\n')
    # Strip trailing whitespace per line
    lines = [line.rstrip() for line in content.split('\n')]
    # Ensure final newline
    return '\n'.join(lines) + '\n'
```

---

### Rule 4: Number Precision

- **Integers:** No decimal point (e.g., `42`, not `42.0`)
- **Floats:** Fixed precision (6 decimal places max unless scientifically necessary)
- **Durations:** Always integers in milliseconds (not fractional seconds)

**Before:**
```json
{
  "confidence": 0.8499999999,
  "duration_ms": 12400.5
}
```

**After:**
```json
{
  "confidence": 0.85,
  "duration_ms": 12401
}
```

---

### Rule 5: Empty Collections

Empty arrays and objects MUST be included explicitly (not omitted).

**Before:**
```json
{
  "findings": null,  // Should be []
  "metadata": null   // Should be {}
}
```

**After:**
```json
{
  "findings": [],
  "metadata": {}
}
```

---

## III. Timestamp Normalization

### Rule 6: ISO 8601 with Timezone

All timestamps MUST be in ISO 8601 format with **UTC timezone** (`Z` suffix).

**Format:** `YYYY-MM-DDTHH:MM:SS.sssZ`

**Examples:**
- ✅ `"2026-02-15T10:30:00.000Z"`
- ✅ `"2026-02-15T10:30:00Z"` (subsecond precision optional if zero)
- ❌ `"2026-02-15T10:30:00"` (missing timezone)
- ❌ `"2026-02-15T10:30:00+00:00"` (use `Z`, not `+00:00`)

**Implementation:**
```python
from datetime import datetime, timezone

def normalize_timestamp(dt: datetime) -> str:
    # Force UTC
    dt_utc = dt.astimezone(timezone.utc)
    # Format with Z suffix
    return dt_utc.strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'
```

---

### Rule 7: Timestamp Policy

Timestamps serve **audit purposes only** and MUST NOT affect:
- **Content hashes**: Exclude timestamps when generating deterministic IDs
- **Deduplication**: Ignore timestamps when comparing findings
- **Ordering**: Use explicit `order` or `sequence` fields, not timestamp comparison

**Content Hash Example:**
```python
def generate_finding_id(finding: dict) -> str:
    # Exclude timestamp and id from hash input
    canonical = {k: v for k, v in finding.items() if k not in ['id', 'timestamp']}
    hash_input = json.dumps(canonical, sort_keys=True)
    return 'FIND-' + hashlib.sha256(hash_input.encode()).hexdigest()[:8].upper()
```

---

## IV. List/Array Normalization

### Rule 8: Stable Ordering

Arrays MUST be sorted deterministically unless order is semantically meaningful.

**Semantic Order Preserved:**
- `plan.steps` (execution order matters)
- `lifecycle.transitions` (sequence matters)

**Deterministic Sort Required:**
- `findings` (sort by: severity desc, category asc, file asc, line asc)
- `affected_files` (sort lexicographically)
- `labels` (sort alphabetically)
- `review_graph.agents` (sort by batch, then agent_id)

**Implementation:**
```python
def sort_findings(findings: List[dict]) -> List[dict]:
    severity_order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3, 'info': 4}
    return sorted(findings, key=lambda f: (
        severity_order.get(f['severity'], 99),
        f['category'],
        f['location']['file'],
        f['location'].get('line', 0)
    ))
```

---

### Rule 9: Deduplication of Arrays

Arrays of strings (e.g., `labels`, `related_tickets`) MUST NOT have duplicates.

**Before:**
```json
{
  "labels": ["feature", "http", "feature", "retry"]
}
```

**After:**
```json
{
  "labels": ["feature", "http", "retry"]
}
```

**Implementation:**
```python
def deduplicate_array(arr: List[str]) -> List[str]:
    return sorted(list(set(arr)))
```

---

## V. String Normalization

### Rule 10: Unicode Normalization

All strings MUST be in **NFC (Canonical Composition)** form.

**Rationale:** Prevents issues with different Unicode representations of the same character.

**Implementation:**
```python
import unicodedata

def normalize_string(s: str) -> str:
    return unicodedata.normalize('NFC', s)
```

---

### Rule 11: Whitespace Trimming

Leading and trailing whitespace in string values MUST be removed (except in `snippet` or `context` fields where whitespace is semantically meaningful).

**Before:**
```json
{
  "message": "  Function is too long  ",
  "snippet": "  fn example() {\n    // ...\n  }  "
}
```

**After:**
```json
{
  "message": "Function is too long",
  "snippet": "  fn example() {\n    // ...\n  }  "
}
```

---

### Rule 12: Path Normalization

File paths MUST be:
- **Relative to project root** (no absolute paths)
- **Forward slashes only** (`/`, not `\`)
- **No leading slash**
- **No `./` prefix**
- **No trailing slash**

**Before:**
```json
{
  "file": "\\src\\http\\client.rs",
  "file": "/Users/damien/project/src/http/client.rs",
  "file": "./src/http/client.rs/"
}
```

**After:**
```json
{
  "file": "src/http/client.rs"
}
```

**Implementation:**
```python
import os

def normalize_path(path: str, project_root: str) -> str:
    # Make absolute
    abs_path = os.path.abspath(path)
    # Make relative to project root
    rel_path = os.path.relpath(abs_path, project_root)
    # Convert to forward slashes
    normalized = rel_path.replace('\\', '/')
    # Remove leading ./
    if normalized.startswith('./'):
        normalized = normalized[2:]
    return normalized
```

---

## VI. ID Generation Rules

### Rule 13: Deterministic ID Generation

IDs MUST be generated from **content hashes**, not random values or timestamps.

**Format:** `{PREFIX}-{8 hex chars}`

**Examples:**
- `FIND-A3F2B8C1` (finding)
- `TASK-00000042` (ticket, sequential)
- `PLAN-7E4C2D9F` (plan)

**Implementation:**
```python
def generate_id(prefix: str, content: dict) -> str:
    # Create canonical representation
    canonical = json.dumps(content, sort_keys=True)
    # Hash
    hash_hex = hashlib.sha256(canonical.encode()).hexdigest()[:8].upper()
    return f"{prefix}-{hash_hex}"
```

---

### Rule 14: ID Stability

Once assigned, IDs MUST NOT change unless content semantically changes.

**Immutable Properties for Findings:**
- `location.file`
- `location.line`
- `category`
- `message` (normalized)

**Mutable Properties (don't affect ID):**
- `timestamp`
- `confidence` (minor adjustments)
- `metadata`

---

## VII. Schema Version Enforcement

### Rule 15: Exact Version Pinning

Schema versions MUST be:
- **Exact strings** (e.g., `"finding.v1"`)
- **Not ranges** (e.g., not `"finding.v1+"`"
- **Not "latest"** (always pin to specific version)

**Version Format:** `{schema_name}.v{major}`

**Examples:**
- ✅ `"finding.v1"`
- ✅ `"test_run.v2"`
- ❌ `"finding.v1.2"` (no minor versions in ID)
- ❌ `"finding_v1"` (use dot separator)

**Implementation:**
```python
import re

def validate_schema_version(version: str) -> bool:
    pattern = r'^[a-z_]+\.v\d+$'
    return re.match(pattern, version) is not None
```

---

## VIII. Diff Normalization

### Rule 16: Unified Diff Format

Code diffs MUST use **unified diff format** with:
- **3 lines of context** before and after changes
- **File paths relative to project root**
- **No timestamps** in diff headers

**Format:**
```diff
--- src/http/client.rs
+++ src/http/client.rs
@@ -45,6 +45,9 @@
 fn execute_with_retries(retries: Vec<Duration>) -> Result<Response> {
+    if retries.is_empty() {
+        return self.execute_once();
+    }
     for delay in retries {
         // ...
     }
```

**Implementation:**
```python
import difflib

def normalize_diff(old_content: str, new_content: str, file_path: str) -> str:
    old_lines = old_content.splitlines(keepends=True)
    new_lines = new_content.splitlines(keepends=True)
    
    diff = difflib.unified_diff(
        old_lines,
        new_lines,
        fromfile=file_path,
        tofile=file_path,
        lineterm='',
        n=3  # 3 lines of context
    )
    
    return ''.join(diff)
```

---

### Rule 17: Example Object Normalization

Ensures deterministic output for `example.v1` artifacts. See [forge.md](../../forge.md) §5.2 (content-based hashing inspired by Git), [artifact-contracts.md](./artifact-contracts.md) (example.v1 schema).

**Rules:**
1. **Field ordering:** `schema_version`, `ticket_id`, `timestamp`, `source_test_id`, `source_layer`, `object_type`, `object_schema`, `serialized_value`, `view_descriptors`, `provenance`, `lineage` (lexicographic within nested objects)
2. **Content-addressed ID:** SHA-256 hash of `serialized_value` field (first 8 hex chars), used as the example's unique identifier when stored in the runtime value store
3. **View descriptor ordering:** `view_descriptors` array sorted by `id` field (lexicographic)
4. **Provenance normalization:** All provenance fields present (use `null` for absent optional fields like `generation_id`)

**Before:**
```json
{
  "lineage": {"ticket_id": "TASK-001", "phase": "example", "depends_on": [], "produced_by": "test-runner"},
  "object_type": "RateLimiter",
  "view_descriptors": [
    {"id": "gauge", "label": "Fill Level", "renderer": "progress_bar", "params": {"field": "tokens", "max_field": "capacity"}},
    {"id": "default", "label": "Token Bucket State", "renderer": "json_tree"}
  ],
  "serialized_value": "{\"capacity\":100,\"fill_rate\":10.0,\"tokens\":75.5}",
  "provenance": {"ticket_id": "TASK-001", "trace_id": "abc123", "code_version": "a1b2c3d4"},
  "source_test_id": "tests::rate_limiter::test_token_bucket",
  "ticket_id": "TASK-001",
  "timestamp": "2026-02-15T10:30:00Z",
  "schema_version": "example.v1",
  "object_schema": {"version": "1.0.0", "fields": {"capacity": "u64", "fill_rate": "f64", "tokens": "f64"}},
  "source_layer": "core"
}
```

**After:**
```json
{
  "schema_version": "example.v1",
  "ticket_id": "TASK-001",
  "timestamp": "2026-02-15T10:30:00Z",
  "source_test_id": "tests::rate_limiter::test_token_bucket",
  "source_layer": "core",
  "object_type": "RateLimiter",
  "object_schema": {
    "fields": {
      "capacity": "u64",
      "fill_rate": "f64",
      "tokens": "f64"
    },
    "version": "1.0.0"
  },
  "serialized_value": "{\"capacity\":100,\"fill_rate\":10.0,\"tokens\":75.5}",
  "view_descriptors": [
    {
      "id": "default",
      "label": "Token Bucket State",
      "renderer": "json_tree"
    },
    {
      "id": "gauge",
      "label": "Fill Level",
      "params": {
        "field": "tokens",
        "max_field": "capacity"
      },
      "renderer": "progress_bar"
    }
  ],
  "provenance": {
    "code_version": "a1b2c3d4",
    "generation_id": null,
    "ticket_id": "TASK-001",
    "trace_id": "abc123"
  },
  "lineage": {
    "depends_on": [],
    "phase": "example",
    "produced_by": "test-runner",
    "ticket_id": "TASK-001"
  }
}
```

**Rationale:** Deterministic ordering and explicit nulls enable stable content-addressed IDs; view descriptor sort ensures reproducible serialization.

---

## IX. Validation Pipeline

Before artifacts enter the external codegen pipeline, run normalization validation:

```python
def validate_artifact(artifact_path: str, schema_path: str) -> ValidationResult:
    # Load artifact
    with open(artifact_path) as f:
        artifact = json.load(f)
    
    # Check 1: Schema conformance
    schema_valid = jsonschema.validate(artifact, schema=load_schema(schema_path))
    
    # Check 2: Key ordering
    canonical_json = normalize_json(artifact)
    with open(artifact_path) as f:
        original_json = f.read()
    keys_ordered = (canonical_json == original_json)
    
    # Check 3: Timestamps are ISO 8601 with Z
    timestamps_valid = all(
        re.match(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z$', ts)
        for ts in extract_timestamps(artifact)
    )
    
    # Check 4: Paths are normalized
    paths_valid = all(
        not path.startswith('/') and '\\' not in path
        for path in extract_paths(artifact)
    )
    
    return ValidationResult(
        schema_valid=schema_valid,
        keys_ordered=keys_ordered,
        timestamps_valid=timestamps_valid,
        paths_valid=paths_valid
    )
```

---

## X. Normalization Checklist (Per Artifact)

Before writing any artifact:

- [ ] Keys sorted lexicographically
- [ ] Nulls explicit, not omitted
- [ ] Whitespace canonical (2-space indent, LF, no trailing, final newline)
- [ ] Numbers at appropriate precision
- [ ] Empty arrays/objects explicit
- [ ] Timestamps in ISO 8601 with Z
- [ ] Lists sorted deterministically (where semantically appropriate)
- [ ] No duplicate array elements
- [ ] Strings trimmed (except code snippets)
- [ ] Paths relative, forward-slash, no leading/trailing slash
- [ ] IDs generated from content hashes
- [ ] Schema version exact, not range
- [ ] Diffs in unified format with 3 lines context
- [ ] Example objects (example.v1): field order, view_descriptors sorted by id, provenance explicit nulls

---

## XI. Example: Before & After Normalization

### Before (Non-Deterministic)

```json
{
  "ticket_id": "FEAT-123",
  "findings": [
    {
      "message": "  Too complex  ",
      "severity": "medium",
      "id": "FIND-12345678",
      "location": {"file": "C:\\Users\\dev\\project\\src\\main.rs", "line": 42},
      "timestamp": "2026-02-15T10:30:00"
    },
    {
      "severity": "high",
      "message": "Missing null check",
      "id": "FIND-87654321",
      "location": {"file": "./src/lib.rs", "line": 15},
      "timestamp": "2026-02-15T10:30:01"
    }
  ],
  "status": "success",
  "schema_version": "review.v1"
}
```

### After (Normalized)

```json
{
  "findings": [
    {
      "id": "FIND-87654321",
      "location": {
        "file": "src/lib.rs",
        "line": 15
      },
      "message": "Missing null check",
      "severity": "high",
      "timestamp": "2026-02-15T10:30:01Z"
    },
    {
      "id": "FIND-12345678",
      "location": {
        "file": "src/main.rs",
        "line": 42
      },
      "message": "Too complex",
      "severity": "medium",
      "timestamp": "2026-02-15T10:30:00Z"
    }
  ],
  "schema_version": "review.v1",
  "status": "success",
  "ticket_id": "FEAT-123"
}
```

**Changes:**
1. Keys sorted alphabetically
2. Findings sorted by severity (high before medium)
3. Paths normalized (relative, forward slashes, no leading `./`)
4. Timestamps have `Z` suffix
5. Message whitespace trimmed
6. All object keys sorted

---

## XII. Tooling

Provide normalization utilities:

```bash
# Normalize artifact in-place
./tools/normalize-artifact.py .claude/artifacts/FEAT-123_review.json

# Validate artifact against schema and normalization rules
./tools/validate-artifact.py .claude/artifacts/FEAT-123_review.json \
    --schema .claude/specs/schemas/review.v1.schema.json

# Batch normalize all artifacts
./tools/normalize-all.sh .claude/artifacts/
```

---

This normalization spec ensures artifacts are **deterministic**, **stable**, and **pipeline-ready**, consistent with [workflow-contract.md](./workflow-contract.md) principles.
