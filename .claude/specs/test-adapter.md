# Test Adapter Interface: Generic Test Execution & Remediation

This specification defines the **universal test adapter interface** for executing tests and remediating failures across any language/project $L$. It abstracts [.claude/agents/test-runner.md](../.claude/agents/test-runner.md) and [.claude/agents/test-fixer.md](../.claude/agents/test-fixer.md) into pluggable components with stable contracts.

---

## I. Overview

The test adapter provides **three core capabilities**:
1. **Executor**: Run tests and capture raw output
2. **Parser**: Transform raw output into structured test results
3. **Fixer**: Analyze failures and generate remediation patches

All adapters conform to **standard input/output contracts**, enabling language-agnostic orchestration.

---

## II. Adapter Interface

### Executor Interface

**Purpose:** Run test commands and capture output.

**Input Contract:**
```json
{
  "command": "cargo test --all -- --nocapture",
  "cwd": "/path/to/project",
  "env": {"RUST_BACKTRACE": "1"},
  "timeout_ms": 300000,
  "capture_streams": ["stdout", "stderr"]
}
```

**Output Contract:**
```json
{
  "status": "success" | "failure" | "timeout",
  "exit_code": 0,
  "stdout": "...",
  "stderr": "...",
  "duration_ms": 12400,
  "timestamp": "2026-02-15T14:00:00Z"
}
```

**Implementation Notes:**
- MUST respect timeout (kill process after `timeout_ms`)
- MUST capture both stdout and stderr (tests may emit to either)
- SHOULD stream output incrementally for long-running suites
- MUST NOT throw exceptions; all errors returned as data

---

### Parser Interface

**Purpose:** Convert raw test output to structured results.

**Input Contract:**
```json
{
  "raw_output": "...",              // From executor
  "format": "cargo_json",           // From profile.toolchain.test_output_format
  "project_profile": {...}          // For context (e.g., test_paths)
}
```

**Output Contract (Normalized Test Results):**
```json
{
  "schema_version": "test_result.v1",
  "summary": {
    "total": 347,
    "passed": 345,
    "failed": 2,
    "skipped": 0,
    "xfailed": 0,                   // Expected failures
    "duration_ms": 12400
  },
  "tests": [
    {
      "id": "tests::retry_logic::test_exponential_backoff",
      "name": "test_exponential_backoff",
      "module": "tests::retry_logic",
      "file": "tests/retry_tests.rs",
      "line": 42,
      "status": "failed",
      "duration_ms": 15,
      "message": "assertion failed: `(left == right)`\n  left: `1000`,\n right: `2000`",
      "traceback": "...",
      "stdout": "",
      "stderr": ""
    },
    {
      "id": "tests::retry_logic::test_max_attempts",
      "name": "test_max_attempts",
      "module": "tests::retry_logic",
      "file": "tests/retry_tests.rs",
      "line": 58,
      "status": "passed",
      "duration_ms": 8
    }
  ]
}
```

**Test Status Values:**
- `passed`: Test succeeded
- `failed`: Test ran and failed assertions/expectations
- `skipped`: Test explicitly skipped (e.g., `@pytest.mark.skip`)
- `xfailed`: Expected to fail and did fail (e.g., `@pytest.mark.xfail`)
- `xpassed`: Expected to fail but passed (usually treated as failure)
- `error`: Test could not run (e.g., setup failure, import error)

**Parser Implementations by Format:**

| Format | Language | Output Pattern | Key Challenges |
|--------|----------|----------------|----------------|
| `cargo_json` | Rust | JSON per-test events | Streaming format; need to aggregate |
| `pytest_json` | Python | JSON summary + per-test | Multiple output modes (`--json`, `-v`) |
| `go_test` | Go | Plain text with structured prefixes | No standard JSON; parse `PASS`/`FAIL` lines |
| `junit_xml` | Many | XML test report | Common interchange format but verbose |
| `jest_json` | JavaScript | JSON summary | Native JSON output |
| `rspec` | Ruby | Text or JSON | Multiple formatters available |

**Implementation Strategy:**
```python
def parse_test_output(raw_output: str, format: str, profile: ProjectProfile) -> TestResults:
    parser = get_parser(format)  # Factory pattern
    return parser.parse(raw_output, context=profile)

class CargoJsonParser:
    def parse(self, raw: str, context: ProjectProfile) -> TestResults:
        # Parse newline-delimited JSON events
        events = [json.loads(line) for line in raw.splitlines() if line.startswith('{')]
        tests = []
        for event in events:
            if event['type'] == 'test':
                tests.append(self._map_test_event(event))
        return TestResults(tests=tests, summary=self._compute_summary(tests))
```

---

### Fixer Interface

**Purpose:** Analyze test failures and generate remediation patches.

**Input Contract:**
```json
{
  "failure": {
    "id": "tests::retry_logic::test_exponential_backoff",
    "file": "tests/retry_tests.rs",
    "line": 42,
    "status": "failed",
    "message": "assertion failed: `(left == right)`\n  left: `1000`,\n right: `2000`",
    "traceback": "..."
  },
  "codebase_context": {
    "test_file_content": "...",     // Full content of tests/retry_tests.rs
    "impl_file_content": "...",     // Related implementation file
    "recent_changes": "..."         // Diff of changes that triggered failure
  },
  "project_profile": {...},
  "previous_fix_attempts": []       // To avoid repeat failures
}
```

**Output Contract:**
```json
{
  "status": "fixable" | "unfixable" | "needs_investigation",
  "confidence": 0.85,               // 0.0 - 1.0
  "risk": "low" | "medium" | "high",
  "failure_category": "assertion_failure" | "runtime_error" | "timeout" | "import_error",
  "root_cause": "Backoff multiplier calculation incorrect",
  "fix": {
    "type": "code_change",          // code_change | test_adjustment | both
    "files": [
      {
        "path": "src/http/retry.rs",
        "changes": [
          {
            "type": "replace",
            "old": "delay * 2",
            "new": "delay * 2.0",
            "line": 87,
            "reason": "Integer division loses precision; use float multiplier"
          }
        ]
      }
    ],
    "verification": "re_run_test"   // How to verify fix worked
  },
  "explanation": "The backoff logic used integer multiplication, causing incorrect delay values."
}
```

**Fixer Decision Tree:**

```
Is this a test failure?
├─ Yes: Analyze type
│  ├─ Assertion failure
│  │  ├─ Check if test expectation is correct → fix implementation
│  │  └─ Check if recent change broke behavior → revert or adjust
│  ├─ Runtime error (panic, exception)
│  │  ├─ Missing null/bounds check? → add defensive code
│  │  └─ Logic error? → fix algorithm
│  ├─ Timeout
│  │  ├─ Infinite loop? → needs investigation
│  │  └─ Performance regression? → profile and optimize
│  └─ Import/setup error
│     └─ Missing dependency or config → unfixable by fixer (needs user)
└─ No: unfixable
```

**Confidence & Risk Scoring:**

```python
def score_fix(failure, fix):
    confidence = 0.5  # Base
    risk = "medium"   # Base
    
    # Increase confidence if:
    if failure.category == "assertion_failure":
        confidence += 0.2
    if fix.type == "code_change" and len(fix.files) == 1:
        confidence += 0.15
    if "trivial typo" in fix.root_cause.lower():
        confidence += 0.25
    
    # Adjust risk if:
    if any(f.path in profile.critical_files for f in fix.files):
        risk = "high"
    if fix.changes involve only test code:
        risk = "low"
    
    return confidence, risk
```

---

## III. Adapter Configuration in Profile

The [project profile](./project-profile-schema.md) specifies which adapters to use:

```yaml
toolchain:
  test_cmd_full: "cargo test --all -- --nocapture --test-threads=1"
  test_cmd_targeted: "cargo test {target} -- --nocapture"
  test_output_format: "cargo_json"  # Maps to parser implementation
  
  executor_config:
    timeout_ms: 300000
    retry_on_timeout: false
    capture_streams: ["stdout", "stderr"]
  
  parser_config:
    format: "cargo_json"
    options:
      aggregate_subtests: true      # Language-specific parser options
  
  fixer_config:
    enabled: true
    max_attempts_per_failure: 3
    confidence_threshold: 0.7       # Minimum to attempt auto-fix
    risk_threshold: "medium"        # Max risk level for auto-fix
```

---

## IV. Skip & Xfail Policy Enforcement

Parsers MUST identify skipped and expected-fail tests. The orchestrator then applies policy from `profile.governance`:

```python
def apply_skip_policy(test_results: TestResults, profile: ProjectProfile) -> GateResult:
    skip_policy = profile.governance.skip_policy
    xfail_policy = profile.governance.xfail_policy
    
    skipped_count = sum(1 for t in test_results.tests if t.status == "skipped")
    xfailed_count = sum(1 for t in test_results.tests if t.status == "xfailed")
    xpassed_count = sum(1 for t in test_results.tests if t.status == "xpassed")
    
    failures = []
    
    # Apply skip policy
    if skipped_count > 0:
        if skip_policy == "fail":
            failures.append(f"Skipped tests not allowed: {skipped_count} tests skipped")
        elif skip_policy == "warn":
            warnings.append(f"Warning: {skipped_count} tests skipped")
        # "allow" = no action
    
    # Apply xfail policy
    if xfailed_count > 0 or xpassed_count > 0:
        if xfail_policy == "fail":
            failures.append(f"Expected-fail tests not allowed: {xfailed_count} xfail, {xpassed_count} xpass")
        elif xfail_policy == "warn":
            warnings.append(f"Warning: {xfailed_count} xfail, {xpassed_count} xpass")
    
    if failures:
        return GateResult(status="failure", errors=failures)
    return GateResult(status="success", warnings=warnings)
```

---

## V. Test Remediation Loop

Mirrors [.claude/agents/test-fixer.md](../.claude/agents/test-fixer.md) remediation protocol:

```
[Run Tests]
    ↓
[Parse Results]
    ↓
Any failures? ──No──→ [Success]
    ↓ Yes
[Classify Failures]
    ↓
For each failure (one at a time):
    ↓
[Fixer: Analyze & Generate Patch]
    ↓
Confidence >= threshold? ──No──→ [Mark unfixable, continue]
    ↓ Yes
[Apply Patch]
    ↓
[Re-run Targeted Tests]
    ↓
Fixed? ──Yes──→ [Continue to next failure]
    ↓ No
[Revert Patch]
    ↓
Attempts < max? ──Yes──→ [Retry with different strategy]
    ↓ No
[Mark unfixable, continue]
    ↓
All fixed? ──Yes──→ [Re-run Full Suite]
    ↓              └──→ [Success]
[Report Unfixable Failures]
```

**Key Invariants:**
1. **One fix at a time**: Never apply multiple patches simultaneously (avoids interaction complexity)
2. **Immediate verification**: Re-run affected tests after each fix
3. **Regression check**: Full suite re-run after all fixes applied
4. **Rollback on failure**: Revert patch if fix doesn't work or breaks other tests
5. **Bounded attempts**: Respect `profile.governance.max_fix_iterations`

---

## VI. Example: Rust Test Execution

### Step 1: Execute

```json
{
  "command": "cargo test --all -- --nocapture --test-threads=1",
  "cwd": "/Users/damien/code/oxide-vm",
  "timeout_ms": 300000
}
```

### Step 2: Parse (Cargo JSON Output)

Raw output:
```json
{"type":"suite","event":"started","test_count":347}
{"type":"test","event":"started","name":"tests::retry_logic::test_exponential_backoff"}
{"type":"test","name":"tests::retry_logic::test_exponential_backoff","event":"failed","stdout":"","message":"assertion failed: ..."}
...
```

Parsed result:
```json
{
  "schema_version": "test_result.v1",
  "summary": {"total": 347, "passed": 346, "failed": 1},
  "tests": [
    {
      "id": "tests::retry_logic::test_exponential_backoff",
      "status": "failed",
      "message": "assertion failed: `(left == right)`\n  left: `1000`,\n right: `2000`"
    }
  ]
}
```

### Step 3: Fix

Input to fixer:
```json
{
  "failure": {...},
  "codebase_context": {
    "test_file_content": "...",
    "impl_file_content": "..."
  }
}
```

Fixer output:
```json
{
  "status": "fixable",
  "confidence": 0.9,
  "risk": "low",
  "fix": {
    "files": [{
      "path": "src/http/retry.rs",
      "changes": [{
        "type": "replace",
        "old": "delay * 2",
        "new": "delay * 2.0",
        "line": 87
      }]
    }]
  }
}
```

### Step 4: Apply & Verify

```bash
# Apply patch
sed -i '' '87s/delay \* 2/delay * 2.0/' src/http/retry.rs

# Re-run targeted test
cargo test tests::retry_logic::test_exponential_backoff -- --nocapture
# → Passes ✓

# Re-run full suite
cargo test --all
# → All pass ✓
```

---

## VII. Language-Specific Parser Examples

### Python (pytest JSON)

```python
class PytestJsonParser:
    def parse(self, raw: str, context: ProjectProfile) -> TestResults:
        data = json.loads(raw)
        tests = []
        for test in data['tests']:
            tests.append({
                "id": test['nodeid'],
                "name": test['nodeid'].split("::")[-1],
                "file": test['nodeid'].split("::")[0],
                "status": self._map_status(test['outcome']),
                "duration_ms": int(test['duration'] * 1000),
                "message": test.get('call', {}).get('longrepr', '')
            })
        return TestResults(tests=tests, summary=self._compute_summary(tests))
    
    def _map_status(self, outcome: str) -> str:
        mapping = {
            "passed": "passed",
            "failed": "failed",
            "skipped": "skipped",
            "xfailed": "xfailed",
            "xpassed": "xpassed"
        }
        return mapping.get(outcome, "error")
```

### Go (plain text)

```python
class GoTestParser:
    def parse(self, raw: str, context: ProjectProfile) -> TestResults:
        tests = []
        for line in raw.splitlines():
            # Go test output format: "--- PASS: TestName (0.01s)"
            match = re.match(r'^--- (PASS|FAIL|SKIP): (\w+) \(([\d.]+)s\)', line)
            if match:
                status, name, duration = match.groups()
                tests.append({
                    "id": name,
                    "name": name,
                    "status": status.lower(),
                    "duration_ms": int(float(duration) * 1000)
                })
        return TestResults(tests=tests, summary=self._compute_summary(tests))
```

---

## VIII. Benefits of Adapter Pattern

1. **Language Agnostic**: Same orchestrator works with any test framework
2. **Pluggable**: Add new parsers without changing workflow logic
3. **Testable**: Each adapter can be unit tested independently
4. **Consistent**: Normalized output schema regardless of source format
5. **Extensible**: Can add custom parsers for proprietary test runners

---

## IX. Integration with Phase Orchestrator

The [phase orchestrator](./phase-orchestrator.md) uses adapters in Phase 4 (Testing):

```python
def run_testing_phase(changes, profile):
    # Execute tests
    executor_result = execute_tests(
        command=profile.toolchain.test_cmd_full,
        config=profile.toolchain.executor_config
    )
    
    # Parse results
    parser = get_parser(profile.toolchain.test_output_format)
    test_results = parser.parse(executor_result.stdout, profile)
    
    # Apply policy
    gate_result = apply_skip_policy(test_results, profile)
    if not gate_result.success:
        return PhaseResult(status="failure", error=gate_result.errors)
    
    # Fix failures
    if test_results.summary.failed > 0:
        fixer_result = run_fixer_loop(test_results, profile)
        if not fixer_result.all_fixed:
            return PhaseResult(status="blocked", unfixed=fixer_result.unfixed_failures)
    
    return PhaseResult(status="success", test_results=test_results)
```

---

## X. Example-Driven Development (EDD)

**Purpose:** Tests that return **explorable example objects**, not just pass/fail results. EDD bridges tests and documentation by making tests produce reusable, inspectable artifacts. Based on [forge.md](../../forge.md) §5.1.

### Per-Language Patterns

**Rust:** Proptests emit `example.v1` artifacts (JSON + binary snapshot). The proptest writes serialized objects to the example store alongside assertions:

```rust
#[test]
fn test_token_bucket_example() {
    let limiter = RateLimiter::new(100, 10.0);
    let example = emit_example(limiter, "RateLimiter", "core");
    assert!(example.object_schema.version == "1.0.0");
}
```

**Python:** Pytest fixtures as example object producers. Fixtures `yield` an object and write it to the example store via `emit_example()`:

```python
@pytest.fixture
def rate_limiter_example():
    limiter = RateLimiter(capacity=100, fill_rate=10.0)
    emit_example(limiter, object_type="RateLimiter", source_layer="core")
    yield limiter
```

**TypeScript:** Storybook stories as explorable examples. Each story exports a live component bound to example data:

```tsx
export const TokenBucketState: Story = {
  args: loadExample("RateLimiter", "default"),
  render: (args) => <TokenBucketGauge {...args} />,
};
```

### Example Artifact Output

EDD artifacts conform to the `example.v1` schema defined in [artifact-contracts.md](./artifact-contracts.md) (Example Objects).

### Integration

- EDD examples become the **smoke examples** used by [hot-reload.md](./hot-reload.md) §V step 6
- Examples are part of the component bundle per [component-model.md](./component-model.md) §VI
- Example Object pattern is detailed in [moldable-canvas.md](./moldable-canvas.md) §IV

### Guard

EDD is active when `extensions.moldable.enabled: true` in the project profile.

---

This adapter interface ensures test execution is **deterministic**, **language-agnostic**, and **policy-driven**, consistent with [workflow-contract.md](./workflow-contract.md) principles.
