<!-- AUTO-GENERATED from .claude/ — do not edit directly. Run: bash .claude/scripts/sync-claude.sh -->
---
name: setup-project
description: First-time project setup: detect language and toolchain, create profile, scaffold directories.
---
# Project Setup

First-time setup for a new project. Detects the language and toolchain, creates a project profile, and scaffolds the required directory structure.

## When to Use

- Cloning the harness-kit into an existing repo for the first time
- Starting a brand-new project from scratch
- Re-initializing after a profile has been deleted or corrupted

## Phase 1: Detect Project

Scan the workspace root and infer the project's identity:

1. **Language detection** — Look for marker files:
   - `Cargo.toml` → Rust
   - `pyproject.toml` / `setup.py` / `requirements.txt` → Python
   - `package.json` → TypeScript/JavaScript
   - `go.mod` → Go
   - `CMakeLists.txt` / `Makefile` → C/C++
   - Multiple markers → Polyglot (list all detected layers)

2. **Toolchain inference** — For each detected language, infer default commands:
   - `test_cmd_full`, `test_cmd_targeted`
   - `format_cmd`, `lint_cmd`
   - `precheck_cmd`, `install_cmd`

3. **Existing profile check** — Read `.claude/profiles/*.yaml` (skip `_template.yaml`). If a valid profile already exists, present it and ask whether to keep, update, or replace it.

## Phase 2: Present Findings

Present a structured summary for the user to confirm or override:

```
## Project Detection Results

**Language:** Python 3.12
**Runtime:** interpreted
**Package manager:** uv (pyproject.toml detected)
**Test framework:** pytest (tests/ directory found)

### Inferred Toolchain
| Command | Value |
|---------|-------|
| precheck | `uv run ruff check .` |
| install | `uv sync` |
| test (full) | `uv run pytest tests/ -v` |
| test (targeted) | `uv run pytest -k` |
| format | `uv run ruff format .` |
| lint | `uv run ruff check . && uv run mypy src/` |

### Governance Defaults
| Policy | Value |
|--------|-------|
| skip_policy | fail |
| xfail_policy | warn |
| max_fix_iterations | 3 |
| autofix_confidence_threshold | 0.7 |

Anything to change? (Or say "looks good" to generate the profile.)
```

Wait for user confirmation before proceeding.

## Phase 3: Generate Profile

1. Read `.claude/profiles/_template.yaml` as the base
2. Fill in all detected values
3. Write to `.claude/profiles/<project-name>.yaml`
4. Validate the generated profile is well-formed YAML

When a polyglot project is detected (Rust + Python + TypeScript, or any project with `extensions.polyglot` configured), the generated profile should include `extensions.moldable`, `extensions.hot_reload`, and `extensions.component_model` blocks — all commented-out with `enabled: false`, matching the format in `_template.yaml`. This follows the same pattern used for `extensions.observability`: the blocks are present for discoverability but disabled by default.

## Phase 4: Scaffold Directories

Ensure the required directory structure exists. Create any missing directories:

```
.claude/
  features/
    todo/
    completed/
  artifacts/
  context/
```

Do NOT overwrite existing files. Only create directories that are missing.

## Phase 5: Context Material Check

Check if `.claude/context/` has any content:

- **If empty:** Inform the user they can add reference docs, code examples, or git submodules here for agents to consult during planning.
- **If populated:** List contents and confirm they're accessible.

## Phase 6: Verify

Run the precheck command from the generated profile to confirm the environment is ready:

```bash
{{toolchain.precheck_cmd}}
```

Present the final status:

```
## Setup Complete

✅ Profile: .claude/profiles/<project>.yaml
✅ Directories: all scaffolded
✅ Precheck: passed

You're ready to go. Next steps:
- `/new-task` to plan features
- `/do-task` to start building
- `/run-tests-and-fix` to verify test health
```

If precheck fails, show the error and suggest fixes. Do NOT proceed silently.
