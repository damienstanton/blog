# Workspace Plasticity: Universal Output Forms

This document explains how the polyglot architecture system enables a **single workspace** to "mold itself" into **any output form** through the harness-kit.

---

## Core Principle: One Source, Many Forms

```
┌───────────────────────────────────────────────┐
│        Natural Language Request               │
│    "Build X as [CLI|Desktop|Web|Mobile]"      │
└───────────────────┬───────────────────────────┘
                    ↓
        ┌───────────────────────┐
        │   Rust Core Logic     │  ← Single source of truth
        │  (Property-tested)    │     Provably correct
        └───────────┬───────────┘
                    ↓
        ┌───────────────────────┐
        │   Diplomat FFI        │  ← Type-safe bridge
        │  (#[diplomat::bridge])│     Automated codegen
        └───────────┬───────────┘
                    ↓
    ┌───────────────┼───────────────┬──────────────┐
    ↓               ↓               ↓              ↓
┌─────────┐   ┌─────────┐   ┌──────────┐   ┌──────────┐
│   CLI   │   │ Desktop │   │   Web    │   │  Mobile  │
│ (clap)  │   │ (Tauri) │   │  (WASM)  │   │ (Tauri)  │
└─────────┘   └─────────┘   └──────────┘   └──────────┘
┌─────────┐   ┌─────────┐   ┌──────────┐   ┌──────────┐
│ Python  │   │   C/C++ │   │  Arduino │   │  ESP32   │
│ Agent   │   │Embedded │   │   (C)    │   │  (Rust)  │
└─────────┘   └─────────┘   └──────────┘   └──────────┘
```

**One Rust implementation → All output forms**

---

## Output Form Matrix

| Form Factor | Layer Name | Agent | Technology Stack | Use Case |
|-------------|-----------|-------|------------------|----------|
| **CLI Tool** | `cli` | `rust_core` | Rust + clap | Command-line utilities |
| **Desktop App** | `desktop` | `tauri_desktop` | Tauri 2 + React + Vite | macOS/Windows/Linux apps |
| **Web App** | `web` | `typescript_ui` | React + WASM + Vite | Browser-based SPA |
| **Mobile App** | `mobile` | `tauri_mobile` | Tauri 2 Mobile (WebView) | iOS/Android/visionOS apps |
| **Python Agent** | `agentic` | `python_agentic` | Python + AI libraries | Data analysis, ML, automation |
| **Embedded** | `embedded` | `c_embedded` | C + bare-metal | Microcontrollers, RTOS |
| **Arduino** | `arduino` | `c_embedded` | C++ Arduino SDK | Arduino boards |
| **ESP32** | `esp32` | `rust_core` | Rust + esp-idf | IoT devices |
| **Library (Native)** | `lib` | `rust_core` | Rust crate | Native library |
| **Library (JS/TS)** | `lib_npm` | `typescript_ui` | npm package via WASM | JavaScript ecosystem |
| **Library (Python)** | `lib_pypi` | `python_agentic` | PyPI package | Python ecosystem |
| **HTTP API** | `api` | `rust_core` | axum/actix-web | REST/GraphQL APIs |

---

## Example 1: Rate Limiter → All Forms

**User:** *"Implement token bucket rate limiter"*

**Core Implementation:** (once, in Rust)

```rust
// core/src/rate_limiter.rs
pub struct RateLimiter {
    max_requests: u32,
    window_secs: u64,
    // ... internal state
}

impl RateLimiter {
    pub fn new(max_requests: u32, window_secs: u64) -> Self { ... }
    pub fn check(&mut self, client_id: &str) -> bool { ... }
}

// Property-tested for correctness
#[cfg(test)]
mod tests {
    use proptest::prelude::*;
    
    proptest! {
        #[test]
        fn never_exceeds_max(max in 1..100u32, reqs in 0..200u32) {
            // Invariant: never allow more than max requests
        }
    }
}
```

**Output Forms:** (automatically generated)

### CLI Tool

```bash
# Generated automatically
cargo build --bin rate-limiter-cli

# Usage
$ rate-limiter check --client user-123
Allowed: true
```

**Implementation:**

```rust
// src/bin/rate-limiter-cli.rs
use clap::{Parser, Subcommand};

#[derive(Parser)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    Check { client: String },
}

fn main() {
    let cli = Cli::parse();
    let mut limiter = RateLimiter::new(100, 60);
    
    match cli.command {
        Commands::Check { client } => {
            println!("Allowed: {}", limiter.check(&client));
        }
    }
}
```

### Desktop App (Tauri)

```typescript
// desktop/src/App.tsx
import { useRateLimiter } from './hooks/useRateLimiter';

function App() {
  const { check, loading } = useRateLimiter();
  
  return (
    <button onClick={() => check('user-123')}>
      Check Rate Limit
    </button>
  );
}
```

**Tauri Command:**

```rust
// desktop/src-tauri/src/commands/rate_limiter.rs
#[tauri::command]
async fn check_rate_limit(
    client_id: String,
    state: State<'_, AppState>,
) -> Result<bool, String> {
    let mut limiter = state.rate_limiter.lock().unwrap();
    Ok(limiter.check(&client_id))
}
```

### Web App (WASM)

```typescript
// web/src/App.tsx
import init, { RateLimiter } from '../pkg/rate_limiter_wasm';

function App() {
  const [limiter, setLimiter] = useState<RateLimiter | null>(null);
  
  useEffect(() => {
    init().then(() => {
      setLimiter(RateLimiter.new(100, 60));
    });
  }, []);
  
  return <button onClick={() => limiter?.check('user-123')}>Check</button>;
}
```

### Python Agent

```python
# agents/rate_limit_monitor.py
from tasker_core import RateLimiter
import pandas as pd

class RateLimitMonitor:
    def __init__(self):
        self.limiter = RateLimiter.new(100, 60)
    
    def analyze_logs(self, df: pd.DataFrame) -> pd.DataFrame:
        df['allowed'] = df['client_id'].apply(self.limiter.check)
        return df[~df['allowed']]  # Return violations
```

### Arduino/ESP32

```cpp
// arduino/rate_limiter.ino
#include "rate_limiter.h"  // Generated C header

RateLimiter* limiter;

void setup() {
    Serial.begin(115200);
    limiter = rate_limiter_new(100, 60);
}

void loop() {
    if (rate_limiter_check(limiter, "sensor-1")) {
        // Log sensor data
        Serial.println("Data logged");
    } else {
        Serial.println("Rate limited");
    }
    delay(1000);
}
```

---

## Example 2: Image Processor → All Forms

**Core:** Gaussian blur algorithm in Rust  
**Forms:**
- **CLI:** `img-blur input.jpg output.jpg --sigma 5.0`
- **Desktop:** Drag-drop GUI with live preview
- **Web:** Browser-based editor (WASM)
- **Mobile:** Photo filter app
- **Python:** Batch processing in Jupyter notebooks
- **Embedded:** Real-time camera preprocessing

**All use the same Rust implementation, tested once, correct everywhere.**

---

## How Workspace "Molds Itself"

### Step 1: User Specifies Target Form

```yaml
# .claude/profiles/project.yaml
extensions:
  polyglot:
    enabled: true
    
    component_layers:
      - layer: "core"      # Always present
      - layer: "desktop"   # User wants desktop app
      - layer: "mobile"    # And mobile app
      - layer: "agentic"   # And Python integration
```

### Step 2: Supervisor Activates Appropriate Agents

```typescript
const requiredAgents = profile.extensions.polyglot.component_layers.map(
  layer => layer.agent
);

// ["rust_core", "tauri_desktop", "tauri_mobile", "python_agentic"]
```

### Step 3: Agents Generate Output-Specific Code

- `rust_core`: Core logic (once)
- `diplomat_ffi`: FFI bridge (once)
- `tauri_desktop`: Desktop app structure
- `tauri_mobile`: Mobile app structure
- `python_agentic`: Python bindings usage

### Step 4: Build System Compiles for All Targets

```bash
# Desktop
cargo tauri build

# Mobile
cargo tauri android build
cargo tauri ios build

# Python
pip install -e agents/

# Web
wasm-pack build --target web
```

### Step 5: Result

```
dist/
├── macos/Tasker.app
├── windows/Tasker.msi
├── linux/tasker.deb
├── android/tasker.apk
├── ios/Tasker.ipa
├── web/index.html
└── python/tasker_core-0.1.0.whl
```

**All from one Rust core!**

---

## Profile-Driven Plasticity

### Minimal Profile (CLI only)

```yaml
component_layers:
  - layer: "core"
    language: "rust"
    agent: "rust_core"
```

**Result:** Just a Rust library/CLI

---

### Full-Stack Profile (Everything)

```yaml
component_layers:
  - layer: "core"      # Rust core
  - layer: "cli"       # Command-line
  - layer: "desktop"   # Tauri desktop
  - layer: "mobile"    # Tauri mobile
  - layer: "web"       # WASM web
  - layer: "api"       # HTTP API
  - layer: "agentic"   # Python agents
  - layer: "embedded"  # C/C++ embedded
  - layer: "arduino"   # Arduino
  - layer: "esp32"     # ESP32/IoT
```

**Result:** Universal toolkit spanning all platforms

---

### IoT-Focused Profile

```yaml
component_layers:
  - layer: "core"
  - layer: "esp32"     # Primary: ESP32 firmware
  - layer: "embedded"  # Secondary: Generic embedded
  - layer: "desktop"   # Configuration tool
  - layer: "mobile"    # Monitoring app
```

**Result:** IoT device + companion apps, shared logic

---

## Technology Integration Matrix

### Build Tools by Layer

| Layer | Package Manager | Build Tool | Test Framework |
|-------|----------------|------------|----------------|
| `core` | Cargo | rustc | cargo test + proptest |
| `desktop` | pnpm | Vite + Tauri CLI | vitest + cargo test |
| `mobile` | pnpm | Tauri 2 Mobile CLI | vitest + XCTest/JUnit |
| `web` | pnpm | Vite + wasm-pack | vitest |
| `agentic` | pip/poetry | setuptools | pytest |
| `embedded` | make/cmake | gcc/arm-gcc | Unity |
| `arduino` | Arduino IDE | arduino-cli | AUnit |
| `esp32` | cargo | espflash | esp-idf tests |

### All Coordinated by Profile

```yaml
build_order:
  - phase: "core"
    command: "cargo build --release"
  
  - phase: "desktop"
    command: "cd desktop && cargo tauri build"
    depends_on: ["core"]
  
  - phase: "mobile_android"
    command: "cd mobile && cargo tauri android build"
    depends_on: ["core"]
  
  - phase: "web"
    command: "cd web && wasm-pack build"
    depends_on: ["core"]
  
  - phase: "esp32"
    command: "cd esp32 && cargo espflash"
    depends_on: ["core"]
```

---

## Benefits of Universal Output

### For Developers

✅ **Write once:** Core logic implemented once in Rust  
✅ **Test once:** Property tests prove correctness for all forms  
✅ **Maintain once:** Bug fixes apply everywhere  
✅ **Type safety:** End-to-end across all layers  
✅ **Performance:** Native speed on all platforms

### For Users

✅ **Consistent:** Same behavior across desktop, mobile, web  
✅ **Reliable:** Property-tested algorithms  
✅ **Fast:** Native Rust performance  
✅ **Secure:** Rust memory safety + Tauri security model  
✅ **Cross-platform:** Run anywhere

### For Organizations

✅ **Reduced costs:** One codebase, not N separate apps  
✅ **Faster shipping:** Parallel development of output forms  
✅ **Lower risk:** Shared logic reduces bugs  
✅ **Team efficiency:** Rust experts write core, UI experts write UI  
✅ **Technology freedom:** Add new output forms without rewriting

---

## Real-World Applications

### 1. Scientific Computing

**Core:** Numerical algorithms in Rust  
**Forms:**
- Desktop app for researchers (Tauri)
- Jupyter notebooks for analysis (Python)
- Web dashboard for results (WASM)
- HPC cluster jobs (Native Rust)

### 2. Embedded + Cloud

**Core:** Device firmware logic  
**Forms:**
- ESP32 firmware (Rust embedded)
- Cloud API for fleet management (axum)
- Mobile app for device control (Tauri Mobile)
- Desktop configuration tool (Tauri Desktop)

### 3. Financial Trading

**Core:** Trading strategy algorithms  
**Forms:**
- CLI backtesting tool
- Desktop monitoring dashboard (Tauri)
- Python analysis notebooks
- C++ HFT integration (for ultra-low latency)

### 4. Game Engine

**Core:** Physics/rendering in Rust  
**Forms:**
- Desktop game editor (Tauri)
- Web player (WASM)
- Mobile builds (Tauri Mobile)
- Embedded hardware displays (C bindings)

---

## The harness-kit Vision

```
User: "I need a task manager"

harness-kit: "What forms?"

User: "Desktop app, mobile app, and Python scripts for automation"

harness-kit: *Activates agents:*
  - rust_core → Implements task scheduler (property-tested)
  - tauri_desktop → Builds macOS/Windows/Linux app
  - tauri_mobile → Builds iOS/Android app
  - python_agentic → Creates automation library

Result: Complete ecosystem from single request
```

**The workspace becomes adaptive:** It materializes whatever output forms you need, all grounded in a single, correct Rust core.

---

## Getting Started

### 1. Define Your Outputs

```yaml
# .claude/profiles/my-project.yaml
extensions:
  polyglot:
    component_layers:
      - layer: "core"
      - layer: "desktop"  # ← Choose your outputs
      - layer: "mobile"
      - layer: "agentic"
```

### 2. Implement Core Logic

```
User: "Implement feature X"
Agent: [Generates Rust core with property tests]
```

### 3. Generate Output Forms

```
Agent: [Activates specialized agents for each layer]
  → Desktop app appears
  → Mobile app appears
  → Python library appears
```

### 4. Build and Deploy

```bash
cargo tauri build              # → Desktop installers
cargo tauri android build      # → Android APK
cargo tauri ios build          # → iOS IPA (also runs on visionOS via iPad compat)
pip install -e agents/         # → Python package
```

**One source → Universal outputs**

---

## Conclusion

This polyglot architecture system enables **workspace plasticity**: the ability for a single workspace to morph into any required output form while maintaining:

- **Correctness:** Property-tested core
- **Safety:** Rust memory safety + FFI soundness
- **Performance:** Native speed everywhere
- **Consistency:** Same behavior across all forms
- **Efficiency:** Write once, deploy everywhere

**The workspace "molds itself" through the harness-kit into exactly what you need, whether that's a CLI tool, desktop app, mobile app, web site, Python library, or embedded firmware.**

**One Rust core → Infinite possibilities.**
