# Polyglot Architecture: Diplomat-Based Vertical Integration

This extension to the [project-profile-schema](./project-profile-schema.md) enables **vertically-complete component** development using Rust + [Diplomat](https://github.com/rust-diplomat/diplomat) as the FFI bridge to multiple target languages.

---

## I. Architecture Overview

```
Natural Language Request
         ↓
    Rust Core Logic (provable algorithms & data structures)
         ↓
    Diplomat FFI Interface (.rs with #[diplomat::bridge])
         ↓
    ┌────────┴────────┬────────────┬──────────┬─────────────┐
    ↓                 ↓            ↓          ↓             ↓
TypeScript UI    Python Agent   C/C++      Tauri         Rust Direct
(Visual/UX)     (Data/AI)    (Embedded)  (Desktop)      (Native)
                                            ↓
                                    React + Vite + pnpm
                                    (Cross-platform apps)
```

**Principle:** One intermediate language (Rust), multiple output languages via automated FFI generation. Tauri bridges Rust backend with TypeScript frontend for desktop applications.

---

## II. Profile Extension Schema

Add to `profile.extensions`:

```yaml
extensions:
  polyglot:
    enabled: true
    mode: "diplomat"                    # FFI bridge technology
    
    # Source of truth
    core_language: "rust"               # The intermediate language
    core_dir: "core/"                   # Where Rust core logic lives
    
    # Diplomat configuration
    diplomat:
      version: "0.7.0"                  # Diplomat version
      bridge_dir: "core/src/ffi/"       # Where #[diplomat::bridge] code lives
      config_file: "diplomat.toml"      # Diplomat configuration
      output_dir: "bindings/"           # Where generated bindings go
      
      # Target languages
      targets:
        - language: "typescript"
          output_path: "bindings/typescript"
          runtime_config:
            module_type: "esm"
            include_dts: true
        
        - language: "python"
          output_path: "bindings/python"
          runtime_config:
            package_name: "{{PROJECT_NAME}}_core"
            use_abi3: true
        
        - language: "c"
          output_path: "bindings/c"
          runtime_config:
            include_headers: true
            link_static: false
    
    # Component layers (vertical completeness)
    component_layers:
      - layer: "core"
        language: "rust"
        directory: "core/"
        role: "algorithms, data structures, business logic"
        agent: "rust_core"
        artifacts: ["*.rs", "Cargo.toml"]
        validation:
          - "cargo check --all"
          - "cargo test --all"
          - "cargo clippy -- -D warnings"
      
      - layer: "ffi"
        language: "rust"
        directory: "core/src/ffi/"
        role: "diplomat bridge definitions"
        agent: "diplomat_ffi_designer"
        artifacts: ["*.rs"]
        validation:
          - "cargo diplomat-verify"
          - "diplomat-tool generate --dry-run"
      
      - layer: "ui"
        language: "typescript"
        directory: "ui/"
        role: "visual components, user experience"
        agent: "typescript_ui"
        depends_on: ["core", "ffi"]
        artifacts: ["*.tsx", "*.ts", "package.json"]
        validation:
          - "npm run type-check"
          - "npm test"
          - "npm run lint"
      
      - layer: "agentic"
        language: "python"
        directory: "agents/"
        role: "data analysis, ML/AI, automation"
        agent: "python_agentic"
        depends_on: ["core", "ffi"]
        artifacts: ["*.py", "pyproject.toml"]
        validation:
          - "mypy ."
          - "pytest"
          - "ruff check ."
      
      - layer: "embedded"
        language: "c"
        directory: "embedded/"
        role: "resource-constrained, real-time systems"
        agent: "c_embedded"
        depends_on: ["core", "ffi"]
        artifacts: ["*.c", "*.h", "Makefile"]
        optional: true  # Not all projects need embedded layer
        validation:
          - "make check"
          - "make test"
      
      - layer: "desktop"
        language: "rust+typescript"
        directory: "desktop/"
        role: "cross-platform desktop apps (Tauri 2)"
        agent: "tauri_desktop"
        depends_on: ["core", "ui"]
        artifacts: ["src-tauri/**/*.rs", "tauri.conf.json", "src/**/*.tsx"]
        optional: true  # Not all projects need desktop apps
        validation:
          - "cd src-tauri && cargo build"
          - "pnpm install && pnpm build"
          - "pnpm test"
      
      - layer: "mobile"
        language: "rust+typescript"
        directory: "mobile/"
        role: "iOS, Android, and visionOS apps (Tauri 2 Mobile)"
        agent: "tauri_mobile"
        depends_on: ["core", "ui"]
        artifacts: ["src-tauri/**/*.rs", "tauri.conf.json", "src/**/*.tsx", "src-tauri/gen/**"]
        optional: true  # Not all projects need mobile apps
        validation:
          - "cd src-tauri && cargo check --target aarch64-apple-ios"
          - "cd src-tauri && cargo check --target aarch64-linux-android"
          - "pnpm install && pnpm build"
    
    # Build orchestration
    build_order:
      - phase: "core"
        command: "cd {{CORE_DIR}} && cargo build --release"
        outputs: ["target/release/lib{{PROJECT_NAME}}_core.*"]
        required: true
      
      - phase: "ffi_validation"
        command: "cd {{CORE_DIR}} && cargo diplomat-verify"
        outputs: []
        required: true
      
      - phase: "diplomat_codegen"
        command: "diplomat-tool generate --config {{DIPLOMAT_CONFIG}}"
        inputs: ["{{CORE_DIR}}/src/ffi/*.rs"]
        outputs: ["{{BINDINGS_DIR}}/typescript/**", "{{BINDINGS_DIR}}/python/**", "{{BINDINGS_DIR}}/c/**"]
        required: true
      
      - phase: "typescript_build"
        command: "cd ui && npm ci && npm run build"
        depends_on: ["diplomat_codegen"]
        outputs: ["ui/dist/**"]
        required: false
      
      - phase: "python_build"
        command: "cd agents && pip install -e ."
        depends_on: ["diplomat_codegen"]
        outputs: ["agents/*.egg-info"]
        required: false
      
      - phase: "embedded_build"
        command: "cd embedded && make"
        depends_on: ["diplomat_codegen"]
        outputs: ["embedded/*.o", "embedded/*.a"]
        required: false
      
      - phase: "tauri_desktop_build"
        command: "cd desktop && pnpm install && cargo tauri build"
        depends_on: ["core", "typescript_build"]
        outputs: ["desktop/src-tauri/target/release/bundle/**"]
        required: false
      
      - phase: "tauri_mobile_ios"
        command: "cd mobile && pnpm install && cargo tauri ios build"
        depends_on: ["core", "typescript_build"]
        outputs: ["mobile/src-tauri/gen/apple/**"]
        required: false
      
      - phase: "tauri_mobile_android"
        command: "cd mobile && pnpm install && cargo tauri android build"
        depends_on: ["core", "typescript_build"]
        outputs: ["mobile/src-tauri/gen/android/**"]
        required: false
    
    # Validation rules
    validation:
      vertical_completeness:
        enabled: true
        required_layers: ["core", "ffi", "ui", "agentic"]  # embedded optional
        check: "each feature must touch all required layers"
      
      ffi_soundness:
        enabled: true
        check: "all Diplomat bridge types are FFI-safe"
        tools: ["cargo diplomat-verify"]
        critical: true
      
      binding_tests:
        enabled: true
        check: "generated bindings have passing tests"
        commands:
          typescript: "cd bindings/typescript && npm test"
          python: "cd bindings/python && pytest"
          c: "cd bindings/c && make test"
      
      cross_layer_integration:
        enabled: true
        check: "end-to-end tests span multiple layers"
        test_patterns: ["tests/e2e/**", "tests/integration/**"]
```

**FFI Safety:** When `extensions.component_model` is enabled, FFI boundaries must follow the rules in [workflow-contract.md](./workflow-contract.md) §II.5: opaque handles only, no borrowed lifetimes across the boundary, result-always-never-panic, versioned interfaces with `interface_hash`, and conformance tests at the boundary. See forge.md §7.3 for the full FFI rule set.

---

## III. Workflow Adaptation

### Phase Orchestration for Polyglot Components

When `extensions.polyglot.enabled == true`, the orchestrator follows a **layered execution model**:

#### Phase 1: Preflight (Enhanced)

Additional checks for polyglot projects:

```yaml
preflight_checks:
  rust_toolchain:
    - "rustc --version"
    - "cargo --version"
    - "cargo install --list | grep diplomat-tool"
  
  target_runtimes:
    - "node --version"  # TypeScript
    - "python --version"  # Python
    - "gcc --version"  # C/C++
  
  diplomat_setup:
    - "diplomat-tool --version"
    - "test -f diplomat.toml"
```

#### Phase 2: Planning (Vertical Decomposition)

Planning agent produces **layer-specific sub-plans**:

```json
{
  "schema_version": "plan.v1",
  "ticket_id": "TASK-001",
  "scope": "extensive",
  "architecture": "polyglot_vertical",
  
  "layers": {
    "core": {
      "steps": [
        {"id": 1, "action": "Define RateLimiter struct", "type": "struct_definition"},
        {"id": 2, "action": "Implement token bucket algorithm", "type": "algorithm_implementation"},
        {"id": 3, "action": "Add property-based tests", "type": "test_addition", "dependencies": [2]}
      ],
      "estimated_complexity": "moderate",
      "risk": "low"
    },
    
    "ffi": {
      "steps": [
        {"id": 4, "action": "Create diplomat bridge module", "type": "ffi_bridge_definition"},
        {"id": 5, "action": "Wrap RateLimiter in opaque type", "type": "ffi_wrapper", "dependencies": [1, 2]},
        {"id": 6, "action": "Add FFI-safe methods", "type": "ffi_methods", "dependencies": [5]}
      ],
      "estimated_complexity": "minimal",
      "risk": "medium",
      "depends_on": ["core"]
    },
    
    "ui": {
      "steps": [
        {"id": 7, "action": "Create RateLimitStatus component", "type": "ui_component"},
        {"id": 8, "action": "Add Storybook story", "type": "docs_addition", "dependencies": [7]}
      ],
      "estimated_complexity": "minimal",
      "risk": "low",
      "depends_on": ["ffi"]
    },
    
    "agentic": {
      "steps": [
        {"id": 9, "action": "Create rate optimizer module", "type": "python_module"},
        {"id": 10, "action": "Add Jupyter example", "type": "docs_addition", "dependencies": [9]}
      ],
      "estimated_complexity": "moderate",
      "risk": "low",
      "depends_on": ["ffi"]
    },
    
    "embedded": {
      "steps": [
        {"id": 11, "action": "Create middleware wrapper", "type": "c_wrapper"}
      ],
      "estimated_complexity": "minimal",
      "risk": "medium",
      "depends_on": ["ffi"]
    },
    
    "mobile": {
      "steps": [
        {"id": 12, "action": "Add mobile Tauri command", "type": "tauri_command"},
        {"id": 13, "action": "Add responsive mobile UI", "type": "ui_component", "dependencies": [12]}
      ],
      "estimated_complexity": "minimal",
      "risk": "low",
      "depends_on": ["core", "ui"]
    }
  },
  
  "execution_strategy": "sequential_layers_parallel_within",
  "layer_order": ["core", "ffi", "codegen", ["ui", "agentic", "embedded", "mobile"]]
}
```

#### Phase 3: Iteration (Layer-Based Execution)

```yaml
iteration_strategy: "layered"

execution_order:
  # Layer 1: Core (sequential, single agent)
  - layer: "core"
    agent: "rust_core"
    mode: "sequential"
    steps: [1, 2, 3]
    validation_per_step:
      - "cargo check"
      - "cargo test {{affected_tests}}"
      - "cargo clippy"
  
  # Layer 2: FFI Bridge (sequential, single agent)
  - layer: "ffi"
    agent: "diplomat_ffi_designer"
    mode: "sequential"
    steps: [4, 5, 6]
    validation_per_step:
      - "cargo check"
      - "cargo diplomat-verify"
      - "no unsafe in bridge code"
  
  # Layer 3: Codegen (supervisor, non-delegated)
  - layer: "codegen"
    agent: "supervisor"
    mode: "sequential"
    action: "run diplomat-tool generate --config diplomat.toml"
    validation:
      - "bindings/typescript exists"
      - "bindings/python exists"
      - "bindings/c exists"
      - "all bindings compile"
  
  # Layer 4: Target Languages (parallel, multiple agents)
  - layer: "targets"
    mode: "parallel"
    max_concurrent: 3
    agents:
      - layer: "ui"
        agent: "typescript_ui"
        steps: [7, 8]
        validation:
          - "tsc --noEmit"
          - "npm test"
      
      - layer: "agentic"
        agent: "python_agentic"
        steps: [9, 10]
        validation:
          - "mypy ."
          - "pytest"
      
      - layer: "embedded"
        agent: "c_embedded"
        steps: [11]
        validation:
          - "make check"
          - "make test"
```

#### Phase 4: Testing (Cross-Layer Integration)

```yaml
testing_strategy: "pyramidal"

test_levels:
  # Unit tests per layer
  - level: "unit"
    parallel: true
    tests:
      - {layer: "core", command: "cargo test --lib"}
      - {layer: "ui", command: "npm test -- --coverage"}
      - {layer: "agentic", command: "pytest --cov"}
      - {layer: "embedded", command: "make test"}
  
  # FFI boundary tests
  - level: "ffi_boundary"
    parallel: true
    tests:
      - {name: "rust_to_typescript", command: "npm test bindings/typescript"}
      - {name: "rust_to_python", command: "pytest bindings/python"}
      - {name: "rust_to_c", command: "make -C bindings/c test"}
  
  # Integration tests
  - level: "integration"
    parallel: false
    tests:
      - {name: "ui_to_core", path: "tests/integration/ui_core_test.ts"}
      - {name: "agentic_to_core", path: "tests/integration/agentic_core_test.py"}
      - {name: "embedded_to_core", path: "tests/integration/embedded_core_test.c"}
  
  # End-to-end tests
  - level: "e2e"
    parallel: false
    tests:
      - {name: "full_vertical_slice", path: "tests/e2e/rate_limit_e2e.test.ts"}
```

#### Phase 5: Review (Multi-Lens with Language Specialization)

```yaml
review_batches:
  - batch: 1
    parallel: true
    blocking: true
    agents:
      - id: "rust_safety"
        lens: "rust_specific"
        focus: ["borrow_checker", "lifetimes", "unsafe_usage"]
        files: ["core/**/*.rs"]
      
      - id: "ffi_soundness"
        lens: "diploma_safety"
        focus: ["repr_c_types", "opaque_pointers", "lifetime_elision", "abi_stability"]
        files: ["core/src/ffi/**/*.rs"]
  
  - batch: 2
    parallel: true
    blocking: false
    agents:
      - id: "typescript_ui_quality"
        lens: "react_best_practices"
        focus: ["component_purity", "hooks_usage", "type_safety"]
        files: ["ui/**/*.tsx", "ui/**/*.ts"]
      
      - id: "python_agentic_quality"
        lens: "data_pipeline_patterns"
        focus: ["type_hints", "pandas_usage", "async_patterns"]
        files: ["agents/**/*.py"]
      
      - id: "c_embedded_quality"
        lens: "embedded_constraints"
        focus: ["memory_bounds", "real_time_guarantees", "misra_c"]
        files: ["embedded/**/*.c", "embedded/**/*.h"]
      
      - id: "tauri_mobile_quality"
        lens: "mobile_best_practices"
        focus: ["safe_areas", "touch_targets", "platform_capabilities", "responsive_design"]
        files: ["mobile/**/*.tsx", "mobile/**/*.ts", "mobile/src-tauri/**/*.rs"]
```

---

## IV. Agent Specializations

### Rust Core Agent

**Agent Definition:** `.claude/agents/rust-core.md`

**Capabilities:**
- `rust_algorithms` — Implement provably correct algorithms
- `data_structures` — Design memory-efficient structures
- `property_testing` — Write proptest-based tests
- `diplomat_types` — Use FFI-safe types

**Constraints:**
- All public types must be `#[repr(C)]` or Diplomat-compatible
- No `unsafe` outside of explicitly documented FFI boundaries
- Algorithm correctness proofs via doc comments
- Comprehensive property-based tests (proptest/quickcheck)

**Output:**
- Core Rust implementations in `core/src/`
- Property-based tests in `core/tests/`
- Benchmarks in `core/benches/`

---

### Diplomat FFI Designer Agent

**Agent Definition:** `.claude/agents/diplomat-ffi.md`

**Capabilities:**
- `ffi_design` — Create minimal FFI surfaces
- `diplomat_bridge` — Write `#[diplomat::bridge]` code
- `abi_safety` — Ensure C ABI compatibility

**Constraints:**
- All bridge types annotated with `#[diplomat::bridge]`
- Use `#[diplomat::opaque]` for complex Rust types
- No complex lifetimes exposed across FFI
- Clear ownership semantics (borrow vs owned)
- Error handling via `Result<T, E>` with FFI-safe errors

When `extensions.component_model.enabled`, the Diplomat FFI agent additionally enforces forge.md v0 FFI rules: opaque handles, explicit ownership, versioned interfaces with `interface_hash`, and conformance test generation. See [workflow-contract.md](./workflow-contract.md) §II.5.

**Output:**
- Diplomat bridge modules in `core/src/ffi/`
- FFI-safe wrapper types
- Error type definitions

---

### TypeScript UI Agent

**Agent Definition:** `.claude/agents/typescript-ui.md`

**Capabilities:**
- `react_components` — Build React/Vue/Svelte components
- `ui_ux` — Design user experiences
- `typescript` — Type-safe frontend code

**Constraints:**
- Use generated TypeScript bindings from `bindings/typescript`
- Components are pure (no business logic)
- All business logic calls delegated to Rust core
- Comprehensive Storybook stories for visual testing
- Accessibility (WCAG AA minimum)

**Output:**
- React components in `ui/src/components/`
- Storybook stories in `ui/src/stories/`
- Integration tests using bindings

---

### Python Agentic Agent

**Agent Definition:** `.claude/agents/python-agentic.md`

**Capabilities:**
- `data_analysis` — Pandas/NumPy pipelines
- `ml_pipelines` — scikit-learn/PyTorch workflows
- `python_agents` — LLM-based agents

**Constraints:**
- Use generated Python bindings from `bindings/python`
- Heavy computation delegated to Rust core
- Type hints for all public APIs (`mypy --strict`)
- Jupyter notebook examples for workflows
- Async-first architecture

**Output:**
- Python modules in `agents/src/`
- Jupyter notebooks in `agents/notebooks/`
- Integration tests with Rust core

---

### C/C++ Embedded Agent

**Agent Definition:** `.claude/agents/c-embedded.md`

**Capabilities:**
- `embedded_systems` — Resource-constrained code
- `c_ffi` — Safe C FFI usage
- `real_time` — Deterministic timing

**Constraints:**
- Use generated C headers from `bindings/c`
- No dynamic allocation in critical paths
- MISRA-C compliance (if specified in profile)
- Hardware abstraction via Rust core
- Static analysis with cppcheck/clang-tidy

**Output:**
- C/C++ wrappers in `embedded/src/`
- Hardware integration tests
- Real-time benchmarks

---

### Tauri Desktop Agent

**Agent Definition:** `.claude/agents/tauri-desktop.md`

**Capabilities:**
- `tauri_commands` — Type-safe IPC between Rust and frontend
- `desktop_apps` — Cross-platform app development
- `react_integration` — Connect React UI with Rust backend

**Constraints:**
- Tauri 2 with `#[tauri::command]` for all IPC
- Frontend uses Vite + pnpm + vitest
- TypeScript hooks for all Tauri commands
- Proper error boundaries for Rust panics
- Security: CSP configured, allowlist minimal
- Cross-platform: macOS, Windows, Linux support

**Output:**
- Tauri backend in `desktop/src-tauri/src/`
- React frontend in `desktop/src/`
- Type-safe hooks in `desktop/src/hooks/`
- Integration tests with vitest
- Bundle configurations for all platforms

**Architecture:**
```
React Frontend (TypeScript)
        ↕ IPC (invoke/emit)
Tauri Commands (Rust)
        ↓
Core Logic (Rust)
```

This enables desktop applications that:
- Use Rust core for computation
- React UI for visualization
- Type-safe IPC via Tauri
- Native OS integration (menus, tray, file system)

---

### Tauri Mobile Agent

**Agent Definition:** `.claude/agents/tauri-mobile.md`

**Capabilities:**
- `tauri_commands` — Type-safe IPC between Rust and frontend
- `mobile_apps` — iOS, Android, and visionOS (iPad compat) development
- `mobile_plugins` — Haptics, biometrics, barcode scanner, geolocation, NFC

**Constraints:**
- Tauri 2 with `#[tauri::command]` for all IPC
- Frontend uses Vite + pnpm + vitest (shared with desktop)
- Responsive design with safe area handling
- Touch targets: 44pt minimum (iOS) / 48dp minimum (Android)
- Mobile capabilities configured in `src-tauri/capabilities/`
- Platform-specific code gated with `#[cfg(target_os = "...")]`

**Output:**
- Tauri backend in `mobile/src-tauri/src/`
- React frontend in `mobile/src/`
- Platform configs in `mobile/src-tauri/gen/apple/` and `mobile/src-tauri/gen/android/`
- Integration tests with vitest

**Architecture:**
```
React Frontend (TypeScript, responsive)
        ↕ IPC (invoke/emit)
Tauri Commands (Rust)
        ↓
Core Logic (Rust)
```

This enables mobile applications that share the same Rust core and React frontend as the desktop app, rendering in a native WebView (WKWebView on iOS, Android WebView on Android).

---

## V. Example: Vertically Complete Component

**Feature:** "Add rate limiting with token bucket algorithm"

### Core (Rust)

```rust
// core/src/rate_limiter.rs
use std::collections::HashMap;
use std::time::{Duration, Instant};

pub struct RateLimiter {
    max_tokens: u32,
    refill_rate: f64,
    clients: HashMap<String, TokenBucket>,
}

struct TokenBucket {
    tokens: f64,
    last_refill: Instant,
}

impl RateLimiter {
    pub fn new(max_requests: u32, window_secs: u64) -> Self {
        Self {
            max_tokens: max_requests,
            refill_rate: max_requests as f64 / window_secs as f64,
            clients: HashMap::new(),
        }
    }
    
    pub fn check(&mut self, client_id: &str) -> bool {
        let bucket = self.clients
            .entry(client_id.to_string())
            .or_insert_with(|| TokenBucket {
                tokens: self.max_tokens as f64,
                last_refill: Instant::now(),
            });
        
        bucket.refill(self.refill_rate, self.max_tokens as f64);
        
        if bucket.tokens >= 1.0 {
            bucket.tokens -= 1.0;
            true
        } else {
            false
        }
    }
}

// Property-based tests
#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;
    
    proptest! {
        #[test]
        fn never_exceeds_limit(max in 1u32..1000, requests in 0usize..10000) {
            let mut limiter = RateLimiter::new(max, 1);
            let allowed = (0..requests)
                .filter(|_| limiter.check("client1"))
                .count();
            prop_assert!(allowed <= max as usize);
        }
    }
}
```

### FFI Bridge (Rust + Diplomat)

```rust
// core/src/ffi/rate_limiter.rs
#[diplomat::bridge]
pub mod ffi {
    use diplomat_runtime::DiplomatStr;
    use super::super::rate_limiter::RateLimiter as RateLimiterImpl;
    
    #[diplomat::opaque]
    pub struct RateLimiter(RateLimiterImpl);
    
    impl RateLimiter {
        pub fn new(max_requests: u32, window_secs: u64) -> Box<RateLimiter> {
            Box::new(RateLimiter(RateLimiterImpl::new(max_requests, window_secs)))
        }
        
        pub fn check(&mut self, client_id: &DiplomatStr) -> bool {
            self.0.check(client_id.as_str())
        }
    }
}
```

### UI (TypeScript)

```typescript
// ui/src/components/RateLimitStatus.tsx
import { RateLimiter } from '@/bindings/typescript';
import { useEffect, useState } from 'react';

export function RateLimitStatus({ clientId }: { clientId: string }) {
  const [limiter] = useState(() => RateLimiter.new(100, 60));
  const [allowed, setAllowed] = useState(true);
  
  const checkLimit = () => {
    setAllowed(limiter.check(clientId));
  };
  
  return (
    <div className={`status ${allowed ? 'allowed' : 'denied'}`}>
      <button onClick={checkLimit}>Check Rate Limit</button>
      <span>{allowed ? '✓ Allowed' : '✗ Rate Limited'}</span>
    </div>
  );
}
```

### Agentic (Python)

```python
# agents/src/rate_optimizer.py
from my_app_core import RateLimiter
import pandas as pd
import numpy as np

def analyze_traffic_patterns(logs_df: pd.DataFrame) -> dict:
    """Analyze traffic to suggest optimal rate limits using Rust core"""
    
    # Fast validation using Rust
    limiter = RateLimiter(max_requests=100, window_secs=60)
    
    violations = []
    for client_id in logs_df['client_id'].unique():
        client_logs = logs_df[logs_df['client_id'] == client_id]
        violation_count = sum(
            not limiter.check(client_id)
            for _ in range(len(client_logs))
        )
        violations.append({
            'client': client_id,
            'violations': violation_count,
            'total_requests': len(client_logs)
        })
    
    # Python ML for pattern analysis
    violations_df = pd.DataFrame(violations)
    return {
        'suggested_limit': int(np.percentile(violations_df['total_requests'], 95)),
        'violation_rate': violations_df['violations'].sum() / violations_df['total_requests'].sum()
    }
```

### Embedded (C)

```c
// embedded/src/middleware.c
#include <rate_limiter.h>
#include <stdio.h>

static RateLimiter* global_limiter = NULL;

void init_rate_limiting(void) {
    if (!global_limiter) {
        global_limiter = RateLimiter_new(100, 60);
    }
}

bool handle_request(const char* client_id) {
    if (!global_limiter) {
        init_rate_limiting();
    }
    
    bool allowed = RateLimiter_check(global_limiter, client_id, strlen(client_id));
    
    if (!allowed) {
        printf("Rate limit exceeded for %s\n", client_id);
    }
    
    return allowed;
}
```

---

## VI. Benefits

1. **Single Source of Truth** — Rust core defines behavior once
2. **Type Safety Across Boundaries** — Diplomat ensures FFI correctness
3. **Best Tool for Job** — Each layer uses optimal language
4. **Automated Binding Generation** — No manual FFI code
5. **Provable Correctness** — Rust's type system + property tests
6. **Vertical Completeness** — Every feature spans all required layers
7. **Parallel Development** — Teams work concurrently after FFI design
8. **Performance** — Zero-cost abstractions in core, efficient bindings

---

This architecture enables **rigorous, polyglot, vertically-integrated development** where correctness is proven in Rust and safety is guaranteed across all language boundaries by Diplomat.
