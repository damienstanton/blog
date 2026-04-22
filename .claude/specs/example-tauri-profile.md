# Example: Full-Stack Desktop App Profile

Complete project profile demonstrating **Tauri 2 + Rust + TypeScript + Python** integration with the polyglot architecture system.

---

## Project Overview

**Name:** `tasker-desktop`  
**Type:** Cross-platform desktop application  
**Stack:**
- **Core Logic:** Rust (provably correct algorithms)
- **Desktop App:** Tauri 2 (macOS, Windows, Linux)
- **Frontend:** React + TypeScript + Vite
- **Testing:** vitest (frontend) + cargo test (backend)
- **Package Manager:** pnpm
- **Data Analysis:** Python (optional, via Diplomat bindings)

---

## Profile Configuration

**File:** `.claude/profiles/tasker-desktop.yaml`

```yaml
schema_version: "profile.v1"

# Project identity
identity:
  project_name: "tasker-desktop"
  language: "rust"
  runtime: "native"
  description: "Cross-platform task management desktop app"
  version: "0.1.0"

# Directory layout
layout:
  root_dir: "."
  core_dir: "core/"
  source_dirs: ["core/src", "desktop/src", "desktop/src-tauri/src"]
  test_dirs: ["core/tests", "desktop/tests"]
  doc_dir: "docs/"
  artifact_dir: ".claude/artifacts/"
  
  # Task tracking
  task_todo_dir: ".claude/features/todo"
  task_completed_dir: ".claude/features/completed"
  tracker_file: ".claude/features/ticket_tracker.md"

# Toolchain commands
toolchain:
  # Rust core
  install_cmd: "cargo build --release"
  test_cmd_full: "cargo test --all"
  test_cmd_targeted: "cargo test {target}"
  test_output_format: "cargo_json"
  lint_cmd: "cargo clippy --all -- -D warnings"
  format_cmd: "cargo fmt --all"
  precheck_cmd: "cargo check --all"
  
  # Frontend
  frontend_install: "cd desktop && pnpm install"
  frontend_build: "cd desktop && pnpm build"
  frontend_test: "cd desktop && pnpm test"
  frontend_lint: "cd desktop && pnpm lint"
  frontend_dev: "cd desktop && pnpm dev"
  
  # Tauri
  tauri_dev: "cd desktop && cargo tauri dev"
  tauri_build: "cd desktop && cargo tauri build"

# Governance
governance:
  skip_policy: "fail"
  xfail_policy: "warn"
  max_fix_iterations: 3
  
  autofix_confidence_rules:
    - condition: "confidence >= 0.9 AND risk == 'low'"
      action: "apply_automatically"
    - condition: "confidence >= 0.7 AND risk == 'low'"
      action: "ask_user"
    - condition: "otherwise"
      action: "log_suggestion"

# Review configuration
review_graph:
  merge_strategy: "union_by_location"
  
  batches:
    - id: 1
      parallel: true
      blocking: true
      agents:
        - "reviewer_specification"
        - "reviewer_safety"
    
    - id: 2
      parallel: true
      blocking: false
      agents:
        - "reviewer_structural"
        - "reviewer_docs"

  agents:
    reviewer_specification:
      model: "claude-opus-4"
      temperature: 0.0
      prompt_template: ".claude/agents/review-correctness-specification.md"
    
    reviewer_safety:
      model: "claude-sonnet-4"
      temperature: 0.0
      prompt_template: ".claude/agents/review-correctness-defensive.md"
    
    reviewer_structural:
      model: "claude-sonnet-4"
      temperature: 0.0
      prompt_template: ".claude/agents/review-quality-structural.md"
    
    reviewer_docs:
      model: "claude-haiku-4"
      temperature: 0.0
      prompt_template: ".claude/agents/review-docs-consistency.md"

# Ticket lifecycle
lifecycle:
  states:
    - "todo"
    - "refined"
    - "in_progress"
    - "blocked"
    - "done"
  
  required_fields:
    - "id"
    - "title"
    - "description"
    - "acceptance_criteria"
  
  transition_rules:
    - from: "todo"
      to: "refined"
      condition: "all required fields complete"
    
    - from: "refined"
      to: "in_progress"
      condition: "preflight validation passed"
    
    - from: "in_progress"
      to: "done"
      condition: "all acceptance criteria met"
  
  definition_of_done:
    - criterion: "All unit tests pass"
      check: "cargo test --all && pnpm test"
    
    - criterion: "No lint warnings"
      check: "cargo clippy && pnpm lint"
    
    - criterion: "Code formatted"
      check: "cargo fmt --check && pnpm format --check"
    
    - criterion: "Cross-platform builds succeed"
      check: "cargo tauri build"
    
    - criterion: "Documentation updated"
      check: "grep -r TODO docs/ | wc -l == 0"

# Execution configuration
execution:
  mode: "supervisor"
  delegation_strategy: "phase_level"
  
  parallelism:
    max_concurrent_phases: 1
    max_concurrent_steps: 3
    max_concurrent_agents: 4
  
  timeout_policies:
    default: 300000  # 5 minutes
    preflight: 60000  # 1 minute
    planning: 120000  # 2 minutes
    iteration: 600000  # 10 minutes
    testing: 300000  # 5 minutes
    review: 180000  # 3 minutes
  
  checkpoint_strategy: "phase_boundary"

# Agent registry
agents:
  # Core workflow agents
  planner:
    capabilities: ["planning", "decomposition"]
    model: "claude-sonnet-4"
    max_concurrent: 1
    prompt_template: ".claude/agents/planner.md"
  
  implementer:
    capabilities: ["code_generation", "formatting", "linting"]
    model: "claude-sonnet-4"
    max_concurrent: 3
    prompt_template: ".claude/agents/implementer.md"
  
  tester:
    capabilities: ["test_execution", "test_fixing"]
    model: "claude-sonnet-4"
    max_concurrent: 1
    prompt_template: ".claude/agents/test-runner.md"
  
  triager:
    capabilities: ["finding_triage", "auto_fixing"]
    model: "claude-sonnet-4"
    max_concurrent: 1
    prompt_template: ".claude/agents/triager.md"
  
  # Polyglot agents
  rust_core:
    capabilities: ["rust_algorithms", "property_testing", "diplomat_types"]
    model: "claude-sonnet-4"
    max_concurrent: 1
    prompt_template: ".claude/agents/rust-core.md"
  
  diplomat_ffi_designer:
    capabilities: ["ffi_bridge", "diplomat_codegen"]
    model: "claude-sonnet-4"
    max_concurrent: 1
    prompt_template: ".claude/agents/diplomat-ffi.md"
  
  typescript_ui:
    capabilities: ["react_components", "typescript", "vite"]
    model: "claude-sonnet-4"
    max_concurrent: 2
    prompt_template: ".claude/agents/typescript-ui.md"
  
  tauri_desktop:
    capabilities: ["tauri_commands", "desktop_apps", "react_integration"]
    model: "claude-sonnet-4"
    max_concurrent: 1
    prompt_template: ".claude/agents/tauri-desktop.md"
  
  python_agentic:
    capabilities: ["data_analysis", "ml_workflows"]
    model: "claude-sonnet-4"
    max_concurrent: 2
    prompt_template: ".claude/agents/python-agentic.md"

# Extensions
extensions:
  # Polyglot architecture
  polyglot:
    enabled: true
    mode: "diplomat"
    core_language: "rust"
    core_dir: "core/"
    
    diplomat:
      version: "0.7.0"
      bridge_dir: "core/src/ffi/"
      config_file: "diplomat.toml"
      output_dir: "bindings/"
      
      targets:
        - language: "typescript"
          output_path: "bindings/typescript"
          runtime_config:
            module_type: "esm"
            include_dts: true
    
    # Component layers
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
          - "cargo check"
      
      - layer: "desktop"
        language: "rust+typescript"
        directory: "desktop/"
        role: "cross-platform desktop app (Tauri 2)"
        agent: "tauri_desktop"
        depends_on: ["core", "ffi"]
        artifacts: ["src-tauri/**/*.rs", "src/**/*.tsx", "tauri.conf.json"]
        validation:
          - "cd src-tauri && cargo build"
          - "pnpm install && pnpm build"
          - "pnpm test"
    
    # Build orchestration
    build_order:
      - phase: "core"
        command: "cargo build --release"
        outputs: ["target/release/libtasker_core.*"]
        required: true
      
      - phase: "ffi_validation"
        command: "cargo check --features diplomat"
        outputs: []
        required: true
      
      - phase: "tauri_desktop"
        command: "cd desktop && pnpm install && cargo tauri build"
        depends_on: ["core", "ffi_validation"]
        outputs: ["desktop/src-tauri/target/release/bundle/**"]
        required: true
    
    # Validation rules
    validation:
      vertical_completeness:
        enabled: true
        required_layers: ["core", "ffi", "desktop"]
        check: "each feature must touch all required layers"
      
      ffi_soundness:
        enabled: false  # Tauri handles FFI internally
        check: "Tauri commands are type-safe"
        critical: true
      
      cross_layer_integration:
        enabled: true
        check: "end-to-end tests span Rust backend and TypeScript frontend"
        test_patterns: ["desktop/tests/integration/**"]
  
  # Observability (optional)
  observability:
    enabled: true
    output_format: "json"
    output_path: ".claude/artifacts/events.jsonl"
    
    events:
      - "phase_start"
      - "phase_complete"
      - "agent_start"
      - "agent_complete"
      - "test_run"
      - "review_finding"
```

---

## Project Structure

```
tasker-desktop/
├── .claude/profiles/
│   └── tasker-desktop.yaml       # This profile
│
├── core/                          # Rust core logic
│   ├── Cargo.toml
│   ├── src/
│   │   ├── lib.rs
│   │   ├── task.rs               # Task data structures
│   │   ├── scheduler.rs          # Scheduling algorithms
│   │   └── ffi/                  # Diplomat FFI (optional)
│   └── tests/
│       └── scheduler_tests.rs
│
├── desktop/                       # Tauri 2 desktop app
│   ├── package.json
│   ├── pnpm-lock.yaml
│   ├── vite.config.ts
│   ├── vitest.config.ts
│   ├── tsconfig.json
│   │
│   ├── src-tauri/                # Rust backend
│   │   ├── Cargo.toml
│   │   ├── tauri.conf.json
│   │   ├── src/
│   │   │   ├── main.rs
│   │   │   └── commands/
│   │   │       └── tasks.rs      # Tauri commands
│   │   └── icons/
│   │
│   ├── src/                      # TypeScript frontend
│   │   ├── main.tsx
│   │   ├── App.tsx
│   │   ├── components/
│   │   │   ├── TaskList.tsx
│   │   │   └── TaskForm.tsx
│   │   └── hooks/
│   │       └── useTasks.ts       # Tauri command hooks
│   │
│   └── tests/
│       ├── unit/
│       │   └── useTasks.test.ts
│       └── integration/
│           └── tasks.test.ts
│
├── .claude/artifacts/             # Generated artifacts
│   ├── TASK-001_plan.json
│   ├── TASK-001_iteration.json
│   └── events.jsonl
│
├── .claude/features/                      # Task tracking
│   ├── todo/
│   ├── completed/
│   └── ticket_tracker.md          # Tracker file at .claude/features/
│
└── docs/
    ├── architecture.md
    └── api.md
```

---

## Usage Examples

### Initialize Workspace

```bash
# Bootstrap the workspace
tools/bootstrap-workspace.py --profile .claude/profiles/tasker-desktop.yaml

# Verify setup
cargo check --all
cd desktop && pnpm install && pnpm build
```

### Develop Feature

**User request:** *"Add task priority sorting"*

**Agent workflow:**

1. **Preflight:** Validate environment
   ```bash
   cargo check --all
   cd desktop && pnpm install
   ```

2. **Planning:** Decompose into steps
   - Step 1: Add priority field to Task struct (Rust core)
   - Step 2: Implement comparison logic (Rust core)
   - Step 3: Add Tauri command for sorting (Tauri backend)
   - Step 4: Update TaskList component (React frontend)
   - Step 5: Add tests

3. **Iteration:** Implement each step
   - `rust_core` agent: Modify `core/src/task.rs`
   - `tauri_desktop` agent: Add command in `desktop/src-tauri/src/commands/tasks.rs`
   - `typescript_ui` agent: Update `desktop/src/components/TaskList.tsx`

4. **Testing:** Run comprehensive tests
   ```bash
   cargo test --all
   cd desktop && pnpm test
   cargo tauri build --debug  # Smoke test build
   ```

5. **Review:** Multi-lens quality checks
   - Specification adherence
   - Runtime safety
   - Code quality
   - Documentation

6. **Triage:** Apply safe auto-fixes

7. **Closure:** Generate artifacts and update ticket

### Run Desktop App

```bash
# Development mode (hot reload)
cd desktop && cargo tauri dev

# Production build
cd desktop && cargo tauri build

# Output:
# - macOS: desktop/src-tauri/target/release/bundle/macos/Tasker.app
# - Windows: desktop/src-tauri/target/release/bundle/msi/Tasker.msi
# - Linux: desktop/src-tauri/target/release/bundle/deb/tasker_0.1.0_amd64.deb
```

---

## Key Files

### `desktop/src-tauri/src/main.rs`

```rust
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;

use commands::tasks::{create_task, get_tasks, update_task, delete_task};
use tasker_core::Scheduler;
use std::sync::Mutex;
use tauri::Manager;

struct AppState {
    scheduler: Mutex<Scheduler>,
}

fn main() {
    tauri::Builder::default()
        .setup(|app| {
            let scheduler = Scheduler::new();
            app.manage(AppState {
                scheduler: Mutex::new(scheduler),
            });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            create_task,
            get_tasks,
            update_task,
            delete_task,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

### `desktop/src/hooks/useTasks.ts`

```typescript
import { invoke } from '@tauri-apps/api/core';
import { useState, useCallback } from 'react';

export interface Task {
  id: string;
  title: string;
  priority: number;
  completed: boolean;
}

export function useTasks() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [loading, setLoading] = useState(false);

  const loadTasks = useCallback(async () => {
    setLoading(true);
    try {
      const result = await invoke<Task[]>('get_tasks');
      setTasks(result);
    } catch (err) {
      console.error('Failed to load tasks:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  const createTask = useCallback(async (title: string, priority: number) => {
    const task = await invoke<Task>('create_task', { title, priority });
    setTasks((prev) => [...prev, task]);
  }, []);

  return { tasks, loading, loadTasks, createTask };
}
```

### `desktop/vite.config.ts`

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  clearScreen: false,
  server: {
    port: 5173,
    strictPort: true,
  },
  envPrefix: ['VITE_', 'TAURI_'],
});
```

### `desktop/vitest.config.ts`

```typescript
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './tests/setup.ts',
  },
});
```

---

## Benefits of This Architecture

✅ **Single Source of Truth:** Rust core implements business logic once  
✅ **Type Safety:** TypeScript frontend + Rust backend with full type checking  
✅ **Cross-Platform:** Single codebase → macOS, Windows, Linux apps  
✅ **Fast Iteration:** Hot reload in dev mode (Vite + Tauri)  
✅ **Property Testing:** Rust algorithms proven correct with proptest  
✅ **Native Performance:** Rust backend, no Electron overhead  
✅ **Secure:** Tauri's security model, no Node.js in production  
✅ **Modern Frontend:** React + TypeScript + Vite tooling

---

## Extending to Mobile/Web

Same profile can be extended with additional layers:

```yaml
component_layers:
  # ... existing layers ...
  
  - layer: "mobile"
    language: "rust+typescript"
    directory: "mobile/"
    role: "iOS, Android, and visionOS apps (Tauri 2 Mobile)"
    agent: "tauri_mobile"
    depends_on: ["core"]
    artifacts: ["src-tauri/**/*.rs", "src/**/*.tsx", "tauri.conf.json", "src-tauri/gen/**"]
    optional: true
    validation:
      - "cd src-tauri && cargo check --target aarch64-apple-ios"
      - "cd src-tauri && cargo check --target aarch64-linux-android"
      - "pnpm install && pnpm build"
  
  - layer: "web"
    language: "typescript"
    directory: "web/"
    role: "web app (SPA with WASM bindings)"
    agent: "typescript_ui"
    depends_on: ["core", "ffi"]

# Add to build_order:
build_order:
  # ... existing phases ...
  
  - phase: "tauri_mobile_ios"
    command: "cd mobile && cargo tauri ios build"
    depends_on: ["core"]
    outputs: ["mobile/src-tauri/gen/apple/**"]
    required: false
  
  - phase: "tauri_mobile_android"
    command: "cd mobile && cargo tauri android build"
    depends_on: ["core"]
    outputs: ["mobile/src-tauri/gen/android/**"]
    required: false
```

The mobile app uses the same React+Vite frontend as desktop, rendered in a native WebView (WKWebView on iOS, Android WebView on Android). visionOS is supported via iPad compatibility mode — apps built for iPad run on Apple Vision Pro without modification.

**Result:** One Rust core → Desktop, Mobile, Web, CLI, Embedded, all from a single workspace!

---

**This profile demonstrates how the polyglot harness-kit "molds itself" to support any output form factor while maintaining a single source of truth.**
