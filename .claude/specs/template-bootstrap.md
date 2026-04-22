# Template Bootstrap: Project Instantiation from Template Repositories

This specification defines how the harness-kit **discovers, analyzes, composes, and instantiates** project templates into a working codebase. Users clone approved template repositories into `.claude/context/`, and the bootstrap system produces the final output project in `the project root`, auto-generating a project profile and adapting the workflow to operate on the result.

---

## I. Overview

The bootstrap system adds a **Phase 0** to the [phase orchestrator](./phase-orchestrator.md), executing before Preflight. It transforms one or more template repositories into a configured, buildable project.

**Flow:**
1. **Discover**: Scan `.claude/context/` for template repositories
2. **Analyze**: Read manifest or infer language/toolchain/layer from file markers
3. **Compose**: Map templates to polyglot component layers, detect conflicts
4. **Instantiate**: Copy templates into `the project root`, substitute placeholders
5. **Configure**: Generate `.claude/profiles/<project>.yaml` from aggregated template metadata
6. **Validate**: Run toolchain precheck on the instantiated project

**Skip Condition:** If `the project root` is already populated and a valid profile exists, Phase 0 is skipped entirely.

---

## II. Directory Convention

```
supertasker/                          # harness-kit workspace root
├── .claude/context/                        # Read-only template repositories
│   ├── example-python-agent/       # git clone target
│   │   ├── .harness-kit-template.yaml     # Optional manifest
│   │   ├── pyproject.toml
│   │   ├── src/
│   │   └── tests/
│   ├── react-spa/                    # Another template
│   │   ├── .harness-kit-template.yaml
│   │   ├── package.json
│   │   └── src/
│   └── rust-core-lib/                # Third template
│       ├── Cargo.toml
│       └── src/
├── .                                    # Project root (bootstrap target)
│   ├── core/                         # ← from rust-core-lib template
│   ├── ui/                           # ← from react-spa template
│   ├── python/                       # ← from example-python-agent template
│   └── ...
├── .claude/profiles/                  # Generated profile lands here
│   └── project.yaml                  # ← auto-generated from templates
├── .claude/features/                         # Ticket lifecycle directories
│   ├── todo/
│   └── completed/
├── .claude/artifacts/                 # Workflow phase artifacts
└── ...
```

**Invariants:**
- `.claude/context/` is treated as **read-only** during bootstrap; originals are never modified
- `the project root` is the **write target**; all subsequent workflow phases operate here
- Each subdirectory of `.claude/context/` is one template repository
- The profile generated during bootstrap drives all Phases 1-7

---

## III. Template Manifest Schema (`.harness-kit-template.yaml`)

A manifest is **optional**. When present at the root of a template repository, it provides explicit metadata. When absent, the system infers equivalent information from file markers (see Section IV).

```yaml
# .harness-kit-template.yaml — Template Manifest (v1)
schema_version: "template.v1"

# --- Identity ---
identity:
  name: "example-python-agent"        # Human-readable template name
  description: "Python agent template with FastAPI, LangChain, and pytest"
  language: "Python"                     # Primary language
  runtime: "interpreted"                 # native | vm | interpreted | browser
  layer: "agentic"                       # Target polyglot layer (see Section VI)
  version: "1.0.0"                       # Template version (semver)
  maintainer: "platform-team@corp.com"   # Optional contact

# --- Toolchain ---
toolchain:
  package_manager: "uv"                  # pip | uv | poetry | npm | pnpm | cargo | go
  package_install_cmd: "uv sync --all-extras --dev"
  precheck_cmd: "uv run ruff check ."
  test_cmd_full: "uv run pytest tests/ -v"
  test_cmd_targeted: "uv run pytest {target} -v"
  test_output_format: "pytest_json"      # cargo_json | pytest_json | jest_json | go_test | junit_xml
  test_framework: "pytest"
  format_cmd: "uv run ruff format ."
  lint_cmd: "uv run ruff check . && uv run mypy src/"
  build_cmd: ""                          # Optional
  clean_cmd: ""                          # Optional

# --- Layout Hints ---
layout:
  src_paths:                             # Source code relative to template root
    - "src/"
  test_paths:
    - "tests/"
  doc_paths:
    - "README.md"
    - "docs/"
  entry_point: "src/main.py"            # Optional: primary entry file

# --- Placeholders ---
# Variables substituted during instantiation.
# Use {{PLACEHOLDER_NAME}} in any file within the template.
placeholders:
  PROJECT_NAME:
    description: "Name of the project"
    default: "my-project"
    pattern: "^[a-z][a-z0-9_-]*$"       # Validation regex
  PACKAGE_NAME:
    description: "Python package name (underscores)"
    default: "my_project"
    pattern: "^[a-z][a-z0-9_]*$"
  AUTHOR:
    description: "Author name"
    default: ""
  LICENSE:
    description: "SPDX license identifier"
    default: "MIT"

# --- Setup ---
# Commands to run after instantiation (in order).
setup:
  - command: "uv sync --all-extras --dev"
    description: "Install dependencies"
    working_dir: "."                     # Relative to instantiated location in the project root
  - command: "uv run ruff check ."
    description: "Verify clean lint"
    working_dir: "."

# --- Compose Rules ---
# How this template interacts with others in a multi-template project.
compose:
  layer: "agentic"                       # Polyglot layer this template targets
  depends_on: []                         # Other layers this template requires
  shared_configs:                        # Files that may need merging with other templates
    - ".gitignore"
    - ".editorconfig"
  exports:                               # Symbols/paths other templates can import
    - type: "python_package"
      path: "src/{{PACKAGE_NAME}}"
  imports: []                            # Symbols/paths this template consumes from others

# --- Files ---
# Optional: files to exclude from instantiation.
exclude:
  - ".git/"
  - ".harness-kit-template.yaml"
  - "node_modules/"
  - "__pycache__/"
  - ".venv/"
```

### Manifest Field Reference

| Section | Field | Required | Description |
|---------|-------|----------|-------------|
| `identity.name` | string | Yes | Unique template name |
| `identity.language` | string | Yes | Primary language |
| `identity.layer` | string | Yes | Target polyglot layer |
| `toolchain.*` | string | No | Toolchain commands (override inference) |
| `placeholders.*` | object | No | Variables for substitution |
| `setup[]` | array | No | Post-instantiation commands |
| `compose.layer` | string | No | Same as `identity.layer` (for clarity) |
| `compose.depends_on` | array | No | Layer dependencies |
| `exclude[]` | array | No | Files to skip during copy |

---

## IV. Inference Heuristics

When a template lacks `.harness-kit-template.yaml`, the system infers metadata from **file markers** — well-known files that indicate language, toolchain, and project structure.

### File Marker Detection

| Marker File | Language | Runtime | Package Manager | Test Framework |
|-------------|----------|---------|-----------------|----------------|
| `Cargo.toml` | Rust | native | cargo | cargo test |
| `pyproject.toml` | Python | interpreted | uv/poetry/pip | pytest |
| `setup.py` | Python | interpreted | pip | pytest |
| `package.json` | TypeScript/JavaScript | browser/vm | npm/pnpm | jest/vitest |
| `go.mod` | Go | native | go | go test |
| `CMakeLists.txt` | C/C++ | native | cmake | ctest |
| `Makefile` (with cc/gcc) | C | native | make | custom |
| `pom.xml` | Java | vm | maven | junit |
| `build.gradle` | Java/Kotlin | vm | gradle | junit |
| `mix.exs` | Elixir | vm | mix | exunit |
| `Gemfile` | Ruby | interpreted | bundler | rspec/minitest |

**Priority:** If multiple markers exist, the system uses the following precedence:
1. `Cargo.toml` (Rust is the canonical core language for polyglot)
2. `package.json` (frontend/UI layers)
3. `pyproject.toml` / `setup.py` (Python layers)
4. `go.mod` (Go layers)
5. `CMakeLists.txt` / `Makefile` (C/C++ embedded)

### Layer Assignment Heuristics

Beyond language detection, the system infers the **polyglot layer** from dependency patterns:

| Signal | Inferred Layer |
|--------|---------------|
| React, Vue, Angular, Svelte in dependencies | `ui` |
| FastAPI, Flask, Django, Express, axum in dependencies | `api` |
| LangChain, transformers, pandas, scikit-learn | `agentic` |
| Tauri in dependencies | `desktop` |
| `#![no_std]` or embedded HAL crates | `embedded` |
| CLI framework (clap, click, cobra) as primary dep | `cli` |
| No UI/API framework, pure library | `core` |

### Toolchain Inference

For each detected language, the system populates toolchain commands from known defaults:

```yaml
# Python (uv detected via uv.lock or [tool.uv] in pyproject.toml)
toolchain:
  package_install_cmd: "uv sync --all-extras --dev"
  precheck_cmd: "uv run python -c 'import sys; print(sys.version)'"
  test_cmd_full: "uv run pytest tests/ -v"
  format_cmd: "uv run ruff format ."
  lint_cmd: "uv run ruff check ."

# Python (poetry detected via poetry.lock)
toolchain:
  package_install_cmd: "poetry install"
  precheck_cmd: "poetry run python -c 'import sys; print(sys.version)'"
  test_cmd_full: "poetry run pytest tests/ -v"
  format_cmd: "poetry run ruff format ."
  lint_cmd: "poetry run ruff check ."

# TypeScript (pnpm detected via pnpm-lock.yaml)
toolchain:
  package_install_cmd: "pnpm install"
  precheck_cmd: "pnpm exec tsc --noEmit"
  test_cmd_full: "pnpm test"
  format_cmd: "pnpm exec prettier --write ."
  lint_cmd: "pnpm exec eslint ."

# Rust
toolchain:
  package_install_cmd: "cargo fetch"
  precheck_cmd: "cargo check --all"
  test_cmd_full: "cargo test --all"
  format_cmd: "cargo fmt --all"
  lint_cmd: "cargo clippy --all -- -D warnings"
```

### REDACTED Dependency Verification

When a Python template targeting the `agentic` or `api` layer is detected, the bootstrap system performs additional verification for REDACTED observability compliance:

**Dependency Check:**
- Verify `agentaware` is present in the template's dependencies (`pyproject.toml` `[project.dependencies]` or `[tool.poetry.dependencies]`)
- If missing, emit a **warning** (not a blocking error): `"Template '{name}' targets layer '{layer}' but does not include 'agentaware' in dependencies. REDACTED SDK is required for the organization observability compliance. See .claude/specs/observability-standard.md."`

**Initialization Check:**
- Scan entry points (e.g., `src/main.py`, `src/__init__.py`, `src/app.py`) for `aa.init(` or `agentaware.init(` calls
- If not found, emit a **warning**: `"Template '{name}' does not appear to initialize REDACTED SDK. Add aa.init() to application entry point."`

**Environment Configuration:**
- Check for `.env.example` or `.env.template` in the template root
- If present, verify it includes `LANGFUSE_HOST`, `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`
- If these variables are missing from the env example, add them during instantiation with placeholder values:

```bash
# REDACTED / Langfuse telemetry (see .claude/specs/observability-standard.md)
LANGFUSE_HOST=https://langfuse.example.com
LANGFUSE_PUBLIC_KEY=pk-lf-REPLACE_ME
LANGFUSE_SECRET_KEY=sk-lf-REPLACE_ME
AGENTAWARE_ENVIRONMENT=development
AA_COMPLIANCE_MODE=warn
```

### Layout Inference

Source, test, and doc paths are inferred from common conventions:

| Language | `src_paths` | `test_paths` | `doc_paths` |
|----------|-------------|-------------|-------------|
| Rust | `["src/"]` | `["tests/", "src/**/test_*.rs"]` | `["README.md", "docs/"]` |
| Python | `["src/"]` or `["<package_name>/"]` | `["tests/"]` | `["README.md", "docs/"]` |
| TypeScript | `["src/"]` | `["tests/", "src/**/*.test.ts"]` | `["README.md", "docs/"]` |
| Go | `["./"]` | `["./**/*_test.go"]` | `["README.md", "docs/"]` |
| C/C++ | `["src/", "include/"]` | `["tests/"]` | `["README.md", "docs/"]` |

---

## V. Bootstrap Workflow

### Phase 0: Bootstrap

**Purpose:** Discover, analyze, compose, and instantiate template repositories into a working project.

**Input Contract:**
```yaml
inputs:
  templates_dir: string              # Default: "templates"
  code_dir: string                   # Default: "code"
  project_name: string               # User-provided or inferred
  placeholder_overrides: object      # Optional: user-provided placeholder values
```

**Transition Rules:**
```yaml
states:
  - idle
  - discovering_templates
  - analyzing_templates
  - resolving_composition
  - awaiting_user_resolution       # If conflicts detected
  - instantiating
  - generating_profile
  - running_setup
  - validating
  - success
  - failure
  - skipped

transitions:
  - {from: idle, event: start, to: discovering_templates}
  - {from: idle, event: code_dir_populated, to: skipped}
  - {from: discovering_templates, event: templates_found, to: analyzing_templates}
  - {from: discovering_templates, event: no_templates, to: failure}
  - {from: analyzing_templates, event: analysis_complete, to: resolving_composition}
  - {from: analyzing_templates, event: unrecognized_template, to: failure}
  - {from: resolving_composition, event: no_conflicts, to: instantiating}
  - {from: resolving_composition, event: conflicts_detected, to: awaiting_user_resolution}
  - {from: awaiting_user_resolution, event: user_resolved, to: instantiating}
  - {from: instantiating, event: copy_complete, to: generating_profile}
  - {from: instantiating, event: copy_failed, to: failure}
  - {from: generating_profile, event: profile_generated, to: running_setup}
  - {from: running_setup, event: setup_complete, to: validating}
  - {from: running_setup, event: setup_failed, to: failure}
  - {from: validating, event: precheck_pass, to: success}
  - {from: validating, event: precheck_fail, to: failure}
```

### Step 1: Discover Templates

Scan `.claude/context/` for subdirectories. Each subdirectory is treated as a candidate template repository.

```python
def discover_templates(templates_dir: str) -> list[TemplateCandidate]:
    candidates = []
    for entry in listdir(templates_dir):
        path = join(templates_dir, entry)
        if isdir(path) and entry != ".git":
            candidates.append(TemplateCandidate(
                name=entry,
                path=path,
                has_manifest=exists(join(path, ".harness-kit-template.yaml"))
            ))
    return candidates
```

**Validation:**
- At least one template must be present
- Empty directories are skipped with a warning

### Step 2: Analyze Templates

For each template, build a `TemplateAnalysis` by reading the manifest or running inference.

```python
def analyze_template(candidate: TemplateCandidate) -> TemplateAnalysis:
    if candidate.has_manifest:
        manifest = parse_yaml(join(candidate.path, ".harness-kit-template.yaml"))
        analysis = TemplateAnalysis.from_manifest(manifest)
    else:
        analysis = TemplateAnalysis.from_inference(candidate.path)

    # Validate analysis has minimum required fields
    assert analysis.language is not None, f"Cannot determine language for {candidate.name}"
    assert analysis.layer is not None, f"Cannot determine layer for {candidate.name}"

    return analysis
```

**TemplateAnalysis Schema:**
```json
{
  "name": "example-python-agent",
  "language": "Python",
  "runtime": "interpreted",
  "layer": "agentic",
  "toolchain": {
    "package_install_cmd": "uv sync --all-extras --dev",
    "precheck_cmd": "uv run ruff check .",
    "test_cmd_full": "uv run pytest tests/ -v",
    "test_cmd_targeted": "uv run pytest {target} -v",
    "test_output_format": "pytest_json",
    "format_cmd": "uv run ruff format .",
    "lint_cmd": "uv run ruff check . && uv run mypy src/"
  },
  "layout": {
    "src_paths": ["src/"],
    "test_paths": ["tests/"],
    "doc_paths": ["README.md"]
  },
  "placeholders": {"PROJECT_NAME": {...}, "PACKAGE_NAME": {...}},
  "setup_commands": [...],
  "compose": {"layer": "agentic", "depends_on": [], "shared_configs": [...]},
  "exclude": [".git/", ".harness-kit-template.yaml"]
}
```

### Step 3: Resolve Composition

When multiple templates are present, map each to a polyglot component layer and detect conflicts.

```python
def resolve_composition(analyses: list[TemplateAnalysis]) -> CompositionPlan:
    layer_map = {}
    conflicts = []

    for analysis in analyses:
        layer = analysis.layer
        if layer in layer_map:
            conflicts.append(LayerConflict(
                layer=layer,
                templates=[layer_map[layer].name, analysis.name]
            ))
        else:
            layer_map[layer] = analysis

    if conflicts:
        return CompositionPlan(status="conflicts", conflicts=conflicts)

    # Build dependency graph
    build_order = topological_sort(layer_map, key=lambda a: a.compose.depends_on)

    return CompositionPlan(
        status="resolved",
        layer_map=layer_map,
        build_order=build_order,
        is_polyglot=len(layer_map) > 1
    )
```

**Conflict Resolution:** When two templates claim the same layer, the system presents the conflict to the user:

```
Conflict detected: Both "example-python-agent" and "data-pipeline"
claim layer "agentic".

Options:
A) Use "example-python-agent" for layer "agentic"
B) Use "data-pipeline" for layer "agentic"
C) Assign "data-pipeline" to a different layer (specify)
```

**Single-Template Shortcut:** When only one template is present, composition is trivial — the template populates `the project root` directly (no layer subdirectory unless the template targets a specific layer in a polyglot setup).

### Step 4: Instantiate Templates

Copy template contents into `the project root`, applying placeholder substitution.

```python
def instantiate(
    composition: CompositionPlan,
    code_dir: str,
    placeholder_values: dict
) -> InstantiationResult:
    for layer, analysis in composition.layer_map.items():
        # Determine target directory
        if composition.is_polyglot:
            target = join(code_dir, layer_to_dirname(layer))
        else:
            target = code_dir

        # Copy files (excluding .git, manifest, etc.)
        for file in walk_template(analysis.path, exclude=analysis.exclude):
            content = read_file(file)
            content = substitute_placeholders(content, placeholder_values, analysis.placeholders)
            dest = join(target, relative_path(file, analysis.path))
            write_file(dest, content)

    # Merge shared configs (.gitignore, .editorconfig)
    merge_shared_configs(composition, code_dir)

    return InstantiationResult(status="success", files_written=count)
```

**Placeholder Substitution Rules:**
1. Placeholders use `{{PLACEHOLDER_NAME}}` syntax (consistent with profile token resolution)
2. Substitution applies to all text files (detected by extension or MIME type)
3. Binary files (images, compiled assets) are copied without substitution
4. Missing placeholder values fall back to `default` from manifest, then to empty string with a warning
5. Placeholder `pattern` is validated before substitution; mismatches produce errors

**Layer-to-Directory Mapping:**

| Layer | Directory in `the project root` |
|-------|---------------------|
| `core` | `core/` |
| `ui` | `ui/` |
| `api` | `api/` |
| `cli` | `cli/` |
| `desktop` | `desktop/` |
| `mobile` | `mobile/` |
| `agentic` | `python/` |
| `embedded` | `embedded/` |
| `arduino` | `arduino/` |
| `esp32` | `esp32/` |

This mapping is consistent with the [polyglot architecture](./polyglot-architecture.md) convention.

### Step 5: Generate Profile

Aggregate template analyses into a project profile.

```python
def generate_profile(
    composition: CompositionPlan,
    project_name: str,
    code_dir: str
) -> ProjectProfile:
    # For single-template projects, use that template's toolchain directly
    if not composition.is_polyglot:
        analysis = list(composition.layer_map.values())[0]
        return ProjectProfile(
            identity=Identity(
                project_name=project_name,
                language=analysis.language,
                runtime=analysis.runtime
            ),
            layout=Layout(
                code_dir=code_dir,
                src_paths=prefix_paths(analysis.layout.src_paths, code_dir),
                test_paths=prefix_paths(analysis.layout.test_paths, code_dir),
                doc_paths=prefix_paths(analysis.layout.doc_paths, code_dir),
                # Standard task/artifact directories remain at workspace root
                task_todo_dir=".claude/features/todo",
                task_completed_dir=".claude/features/completed",
                tracker_file=".claude/features/ticket_tracker.md",
                artifacts_dir=".claude/artifacts"
            ),
            toolchain=analysis.toolchain,
            governance=DEFAULT_GOVERNANCE,
            review_graph=DEFAULT_REVIEW_GRAPH,
            lifecycle=DEFAULT_LIFECYCLE,
            execution=Execution(mode="monolithic"),
            extensions=Extensions(
                bootstrap=BootstrapRecord(
                    templates=[analysis.name],
                    instantiated_at="<timestamp>"
                )
            )
        )

    # For polyglot projects, compose toolchains per layer
    return generate_polyglot_profile(composition, project_name, code_dir)
```

**REDACTED Profile Generation:**

When generating a profile from a Python template (or any template with an `agentic` or `api` layer), the bootstrap system auto-populates `extensions.observability` with REDACTED defaults:

```python
def populate_observability_config(
    profile: ProjectProfile,
    composition: CompositionPlan,
    project_name: str,
) -> ProjectProfile:
    # Check if any template targets agentic/api layers or is a Python project
    has_python_layer = any(
        a.language == "Python" or a.layer in ("agentic", "api")
        for a in composition.layer_map.values()
    )

    if has_python_layer:
        profile.extensions.observability = ObservabilityConfig(
            enabled=True,
            provider="agentaware",
            spec_version="1.1.0",
            identity=ObsIdentity(
                app_id=project_name,
                agent_id="",       # Subagents override
            ),
            sensitivity=SensitivityConfig(
                default_type="INTERNAL",
                default_labels=["SOURCE_CODE"],
            ),
            cdo=CDOConfig(
                enabled=False,
                default_operation="read",
            ),
            compliance=ComplianceConfig(
                mode="warn",
            ),
        )

    return profile
```

When a template's `.harness-kit-template.yaml` manifest includes its own observability configuration, those values take precedence over the auto-generated defaults. This allows templates to ship with pre-configured sensitivity levels, data governance settings, and Langfuse endpoints.

**Polyglot Profile Generation:**

When multiple templates produce a polyglot project, the generated profile includes:
- `identity.language` set to the core layer's language (or the first template's language)
- `extensions.polyglot.enabled: true`
- `extensions.polyglot.component_layers` populated from the composition plan
- `extensions.polyglot.build_order` from the dependency graph
- Per-layer toolchain commands prefixed with the layer's directory path

```yaml
# Generated profile for a 3-template polyglot project
identity:
  project_name: "my-project"
  language: "Rust"                  # Core layer language
  runtime: "native"

layout:
  code_dir: "."
  templates_dir: "context"
  src_paths:
    - "core/src/"
    - "ui/src/"
    - "python/src/"
  test_paths:
    - "core/tests/"
    - "ui/tests/"
    - "python/tests/"

extensions:
  polyglot:
    enabled: true
    core_language: "rust"
    component_layers:
      - name: "core"
        language: "rust"
        directory: "core"
        agent: "rust_core"
      - name: "ui"
        language: "typescript"
        directory: "ui"
        agent: "typescript_ui"
      - name: "agentic"
        language: "python"
        directory: "python"
        agent: "python_agentic"

    build_order:
      - phase: "core"
        command: "cargo build --release"
        working_dir: "core"
      - phase: "ui"
        command: "pnpm install && pnpm build"
        working_dir: "ui"
        depends_on: ["core"]
      - phase: "agentic"
        command: "uv sync --all-extras --dev"
        working_dir: "python"
        depends_on: ["core"]

  bootstrap:
    templates:
      - source: ".claude/context/rust-core-lib"
        layer: "core"
      - source: ".claude/context/react-spa"
        layer: "ui"
      - source: ".claude/context/example-python-agent"
        layer: "agentic"
    instantiated_at: "2026-02-17T10:00:00Z"
```

### Step 6: Run Setup Commands

Execute post-instantiation setup commands from each template's manifest.

```python
def run_setup(composition: CompositionPlan, code_dir: str) -> SetupResult:
    results = []
    for layer, analysis in composition.layer_map.items():
        if not analysis.setup_commands:
            continue

        layer_dir = join(code_dir, layer_to_dirname(layer)) if composition.is_polyglot else code_dir

        for cmd in analysis.setup_commands:
            working_dir = join(layer_dir, cmd.working_dir)
            result = execute_command(cmd.command, cwd=working_dir)
            results.append(SetupStepResult(
                command=cmd.command,
                layer=layer,
                exit_code=result.exit_code,
                stdout=result.stdout,
                stderr=result.stderr
            ))
            if result.exit_code != 0:
                return SetupResult(status="failure", steps=results)

    return SetupResult(status="success", steps=results)
```

### Step 7: Validate

Run toolchain precheck on the instantiated project to confirm it builds/imports cleanly.

```python
def validate_bootstrap(profile: ProjectProfile) -> ValidationResult:
    # Verify code_dir is non-empty
    if not listdir(profile.layout.code_dir):
        return ValidationResult(status="failure", error="code_dir is empty after instantiation")

    # Verify profile schema
    schema_errors = validate_profile_schema(profile)
    if schema_errors:
        return ValidationResult(status="failure", error=schema_errors)

    # Run precheck
    result = execute_command(profile.toolchain.precheck_cmd, cwd=profile.layout.code_dir)
    if result.exit_code != 0:
        return ValidationResult(
            status="failure",
            error=f"Precheck failed: {result.stderr}",
            precheck_output=result.stdout
        )

    return ValidationResult(status="success")
```

---

## VI. Polyglot Layer Registry

The layer system connects templates to the [polyglot architecture](./polyglot-architecture.md) and [workspace plasticity](./workspace-plasticity.md) systems.

### Standard Layers

| Layer | Purpose | Canonical Agent | Typical Languages |
|-------|---------|-----------------|-------------------|
| `core` | Business logic, algorithms | `rust-core` | Rust, Go |
| `ui` | Frontend user interface | `typescript-ui` | TypeScript, JavaScript |
| `api` | HTTP/GraphQL server | `rust-core` or `python-agentic` | Rust, Python, Go |
| `cli` | Command-line interface | `rust-core` | Rust, Go, Python |
| `desktop` | Desktop application | `tauri-desktop` | Rust + TypeScript |
| `mobile` | Mobile application | `tauri-desktop` | Rust + TypeScript |
| `agentic` | AI/ML/data workflows | `python-agentic` | Python |
| `embedded` | Embedded systems | `c-embedded` | C, C++ |
| `arduino` | Arduino firmware | `c-embedded` | C++ |
| `esp32` | ESP32 IoT firmware | `rust-core` | Rust |

### Custom Layers

Templates may define custom layers not in the standard registry. Custom layers are supported but:
- Must have a unique name (no collisions with standard layers)
- Must specify their agent explicitly in the manifest
- Are placed in `<layer_name>/`

---

## VII. Artifact Output

Bootstrap produces the standard dual-output artifacts.

### JSON Artifact: `.claude/artifacts/TASK-<N>_bootstrap.json`

```json
{
  "schema_version": "bootstrap.v1",
  "lineage": {
    "phase": "bootstrap",
    "ticket_id": null,
    "produced_by": "bootstrap_orchestrator"
  },
  "status": "success",
  "templates_discovered": [
    {
      "name": "example-python-agent",
      "path": ".claude/context/example-python-agent",
      "has_manifest": true,
      "language": "Python",
      "layer": "agentic"
    },
    {
      "name": "react-spa",
      "path": ".claude/context/react-spa",
      "has_manifest": true,
      "language": "TypeScript",
      "layer": "ui"
    }
  ],
  "composition": {
    "is_polyglot": true,
    "layer_map": {
      "agentic": "example-python-agent",
      "ui": "react-spa"
    },
    "build_order": ["ui", "agentic"],
    "conflicts_resolved": []
  },
  "instantiation": {
    "code_dir": "code",
    "files_written": 47,
    "placeholders_substituted": {
      "PROJECT_NAME": "my-project",
      "PACKAGE_NAME": "my_project"
    }
  },
  "profile_generated": ".claude/profiles/my-project.yaml",
  "setup_results": [
    {"command": "pnpm install", "layer": "ui", "exit_code": 0},
    {"command": "uv sync --all-extras --dev", "layer": "agentic", "exit_code": 0}
  ],
  "validation": {
    "code_dir_populated": true,
    "profile_valid": true,
    "precheck_passed": true
  },
  "timestamp": "2026-02-17T10:00:00Z"
}
```

### Markdown Artifact: `.claude/artifacts/TASK-<N>_bootstrap.md`

```markdown
# Bootstrap Report

## Templates Discovered

| Template | Language | Layer | Manifest |
|----------|----------|-------|----------|
| example-python-agent | Python | agentic | Yes |
| react-spa | TypeScript | ui | Yes |

## Composition

- **Polyglot:** Yes
- **Layers:** ui, agentic
- **Conflicts:** None

## Instantiation

- **Target:** project root
- **Files written:** 47
- **Placeholders:** PROJECT_NAME=my-project, PACKAGE_NAME=my_project

## Setup

| Command | Layer | Result |
|---------|-------|--------|
| pnpm install | ui | OK |
| uv sync --all-extras --dev | agentic | OK |

## Validation

- Code directory populated: Yes
- Profile generated: `.claude/profiles/my-project.yaml`
- Precheck passed: Yes

## Generated Profile

Path: `.claude/profiles/my-project.yaml`
```

---

## VIII. Error Handling

Following [workflow-contract.md](./workflow-contract.md) Section II.4, all errors are data.

```typescript
type BootstrapResult =
  | {status: "success", profile: ProjectProfile, artifacts: Artifact[]}
  | {status: "failure", error: BootstrapError, partial_artifacts: Artifact[]}
  | {status: "blocked", reason: string, requires_user: true}
  | {status: "skipped", reason: "code_dir_already_populated"}
```

### Error Catalog

| Error Code | Phase | Description | Recovery |
|------------|-------|-------------|----------|
| `NO_TEMPLATES` | Discover | `.claude/context/` is empty | Clone a template into .claude/context/ |
| `UNRECOGNIZED_TEMPLATE` | Analyze | Cannot determine language/layer | Add `.harness-kit-template.yaml` manifest |
| `LAYER_CONFLICT` | Compose | Two templates claim same layer | User resolves interactively |
| `PLACEHOLDER_INVALID` | Instantiate | Value fails pattern validation | Provide valid placeholder value |
| `COPY_FAILED` | Instantiate | File system error during copy | Check permissions and disk space |
| `SETUP_FAILED` | Setup | Post-instantiation command failed | Check command and dependencies |
| `PRECHECK_FAILED` | Validate | Toolchain precheck failed | Fix build errors in template |
| `PROFILE_INVALID` | Configure | Generated profile fails schema validation | File a bug against the template |

---

## IX. Integration with Phase Orchestrator

Phase 0 (Bootstrap) sits before Phase 1 (Preflight) in the [phase orchestrator](./phase-orchestrator.md):

```
┌──────────────┐
│  Bootstrap   │  ← Phase 0 (NEW)
│  (Phase 0)   │
└──────┬───────┘
       │ success / skipped
       ▼
┌──────────────┐
│  Preflight   │  ← Phase 1 (existing)
│  (Phase 1)   │
└──────┬───────┘
       │
       ▼
      ...        ← Phases 2-7 (unchanged)
```

**Updated Composition:**
```python
def run_workflow(ticket_id, profile, templates_dir="templates", code_dir="code"):
    # Phase 0: Bootstrap (conditional)
    bootstrap_result = bootstrap(templates_dir, code_dir, profile)
    if bootstrap_result.status == "failure":
        return bootstrap_result
    if bootstrap_result.status == "success":
        profile = bootstrap_result.profile  # Use generated profile

    # Phase 1: Preflight (existing)
    result = preflight(ticket_id, profile)
    if not result.success: return result

    # Phases 2-7 (unchanged)
    ...
```

**Profile Path Resolution:** After bootstrap, all `layout.*` paths in the profile are relative to the workspace root. Source/test/doc paths are at the project root. Task and artifact directories remain at the workspace root level.

---

## X. Observability

Bootstrap emits structured events consistent with [phase-orchestrator.md](./phase-orchestrator.md) Section VI:

```json
{"event": "phase_start", "phase": "bootstrap", "timestamp": "2026-02-17T10:00:00Z"}
{"event": "templates_discovered", "count": 2, "templates": ["example-python-agent", "react-spa"], "timestamp": "..."}
{"event": "template_analyzed", "name": "example-python-agent", "language": "Python", "layer": "agentic", "source": "manifest", "timestamp": "..."}
{"event": "composition_resolved", "is_polyglot": true, "layers": ["ui", "agentic"], "timestamp": "..."}
{"event": "instantiation_complete", "files_written": 47, "timestamp": "..."}
{"event": "profile_generated", "path": ".claude/profiles/my-project.yaml", "timestamp": "..."}
{"event": "setup_step", "command": "pnpm install", "layer": "ui", "exit_code": 0, "duration_ms": 8500, "timestamp": "..."}
{"event": "phase_complete", "phase": "bootstrap", "status": "success", "duration_ms": 15000, "timestamp": "..."}
```

---

## XI. Examples

### Example 1: Single Python Agent Template

**Setup:**
```bash
cd supertasker
git clone https://github.com/corp/python-agent-template .claude/context/python-agent
```

**Bootstrap runs:**
1. Discovers 1 template: `python-agent`
2. Reads `.harness-kit-template.yaml` — language: Python, layer: agentic
3. Single template, no composition needed
4. Copies to `the project root` (flat, no layer subdirectory)
5. Substitutes `{{PROJECT_NAME}}` with "my-agent"
6. Generates `.claude/profiles/my-agent.yaml` with Python toolchain
7. Runs `uv sync --all-extras --dev` in `the project root`
8. Validates: `uv run ruff check .` passes

**Result:**
```
the project root
├── pyproject.toml
├── src/
│   └── my_agent/
│       ├── __init__.py
│       └── main.py
├── tests/
│   └── test_main.py
└── README.md
```

### Example 2: Polyglot — Rust Core + React UI + Python Agent

**Setup:**
```bash
git clone https://github.com/corp/rust-core-template .claude/context/rust-core
git clone https://github.com/corp/react-spa-template .claude/context/react-spa
git clone https://github.com/corp/python-agent-template .claude/context/python-agent
```

**Bootstrap runs:**
1. Discovers 3 templates
2. Analyzes: Rust→core, TypeScript→ui, Python→agentic
3. Composition: 3 layers, no conflicts, build order: core → ui, agentic (parallel)
4. Instantiates into `core/`, `ui/`, `python/`
5. Generates polyglot profile with `extensions.polyglot.enabled: true`
6. Runs setup per layer (cargo fetch, pnpm install, uv sync)
7. Validates each layer's precheck

**Result:**
```
the project root
├── core/
│   ├── Cargo.toml
│   ├── src/
│   │   └── lib.rs
│   └── tests/
├── ui/
│   ├── package.json
│   ├── src/
│   │   ├── App.tsx
│   │   └── main.tsx
│   └── tests/
└── python/
    ├── pyproject.toml
    ├── src/
    │   └── my_project/
    └── tests/
```

### Example 3: Template Without Manifest (Inference Only)

**Setup:**
```bash
git clone https://github.com/colleague/fastapi-starter .claude/context/api-starter
# This template has no .harness-kit-template.yaml
```

**Bootstrap runs:**
1. Discovers 1 template: `api-starter`
2. No manifest — runs inference:
   - Finds `pyproject.toml` → Python
   - Finds FastAPI in dependencies → `api` layer
   - Detects `uv.lock` → uv package manager
   - Finds `tests/` directory → pytest
3. Single template, copies to `the project root`
4. No placeholders (none defined), straight copy
5. Generates profile from inferred toolchain
6. Runs `uv sync --all-extras --dev`
7. Validates

---

## XII. Validation Strategy

### Template Validation

Before instantiation, validate each template:

1. **Structure**: At least one source file exists
2. **Manifest Schema**: If `.harness-kit-template.yaml` present, it conforms to `template.v1` schema
3. **Placeholder Consistency**: All `{{PLACEHOLDER}}` references in files match declared placeholders
4. **Toolchain Commands**: Commands reference real tools (existence check, not execution)

### Post-Bootstrap Validation

After instantiation:

1. **Code Directory**: Project root is non-empty with expected structure
2. **Profile Schema**: Generated profile validates against [project-profile-schema.md](./project-profile-schema.md)
3. **Toolchain Precheck**: All `profile.toolchain.*_cmd` are executable
4. **Build Precheck**: `profile.toolchain.precheck_cmd` exits 0
5. **Artifact Schema**: Bootstrap artifact validates against `bootstrap.v1` schema

---

## XIII. Relationship to Other Specs

| Spec | Relationship |
|------|-------------|
| [phase-orchestrator.md](./phase-orchestrator.md) | Bootstrap is Phase 0, predecessor to Preflight |
| [project-profile-schema.md](./project-profile-schema.md) | Bootstrap generates profiles conforming to this schema |
| [polyglot-architecture.md](./polyglot-architecture.md) | Multi-template composition produces polyglot projects |
| [workspace-plasticity.md](./workspace-plasticity.md) | Templates are the input; plasticity is the output capability |
| [workflow-contract.md](./workflow-contract.md) | Bootstrap follows CTT invariants (error as data §VIII, bounded computation §VIII, deterministic transitions §II) |
| [normalization-rules.md](./normalization-rules.md) | Bootstrap artifacts follow normalization rules |
| [artifact-contracts.md](./artifact-contracts.md) | Bootstrap emits dual JSON+Markdown artifacts |
| [observability-standard.md](./observability-standard.md) | Bootstrap verifies REDACTED dependencies and generates observability config |
| REDACTED Spec (external) | Authoritative REDACTED protocol referenced during dependency verification |
