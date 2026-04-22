<!-- AUTO-GENERATED from .claude/ — do not edit directly. Run: bash .claude/scripts/sync-claude.sh -->
---
name: reset-workflow
description: Reset the repo to a clean template state by clearing tickets, artifacts, and tracker.
---
# Reset Workflow

Return the harness-kit repo to a clean template state by removing all project-specific workflow state. Use this before distributing the template or after cloning to start fresh.

## When to Use

- Preparing the harness-kit repo for distribution as a clean template
- After cloning the template to start a new project (clearing inherited development history)
- Resetting a project to start fresh without re-cloning
- Cleaning up after experimentation or testing

## Phase 1: Inventory

Scan the workspace and categorize everything into **always clear**, **conditionally clear**, and **always preserve**.

### 1.1 Always Clear (No Prompt Needed)

These are project-specific workflow artifacts that should never ship in a template:

| Path | Contents |
|------|----------|
| `.claude/features/todo/*.json` | In-progress ticket JSON files |
| `.claude/features/todo/*.md` | In-progress ticket Markdown files |
| `.claude/features/completed/*.json` | Completed ticket JSON files |
| `.claude/features/completed/*.md` | Completed ticket Markdown files |
| `.claude/features/ticket_tracker.md` | Reset to empty table header |
| `.claude/artifacts/*` | Active phase artifacts and manifests |
| `.claude/artifacts-archive/**/*` | Archived artifacts from completed tickets |

### 1.2 Conditionally Clear (Interactive)

These may or may not be project-specific:

| Path | Why Interactive |
|------|----------------|
| `.claude/profiles/<name>.yaml` | May be a project-specific profile created by `/setup-project` |
| `.claude/context/<name>/` | May be reference material or template source (submodule or symlink) added by `/add-codebase` |

**Protected profiles** (never removed):
- `_template.yaml` — the profile template
- `example-*.yaml` — example/reference profiles

### 1.3 Always Preserve

These are the template infrastructure and are never touched:

- `.claude/agents/` — all agent definitions
- `.claude/rules/` — all governance rules
- `.claude/specs/` — all specifications
- `.claude/commands/` — all slash commands
- `.claude/profiles/_template.yaml`
- `.claude/profiles/example-*.yaml`
- `AGENTS.md`
- `README.md`

## Phase 2: Dry-Run Preview

Before executing anything, present a complete preview of what will happen.

### 2.1 Scan and Count

```bash
# Count ticket files
ls .claude/features/todo/*.json .claude/features/todo/*.md 2>/dev/null | wc -l
ls .claude/features/completed/*.json .claude/features/completed/*.md 2>/dev/null | wc -l

# Count artifacts
ls .claude/artifacts/ 2>/dev/null | wc -l
ls -R .claude/artifacts-archive/ 2>/dev/null | wc -l

# Find non-template profiles
ls .claude/profiles/*.yaml  # filter out _template.yaml and example-*.yaml

# Find context submodules
ls .claude/context/ 2>/dev/null
```

### 2.2 Present Preview

```
## Reset Workflow — Dry Run

### Will Be Cleared
| Category | Count | Details |
|----------|-------|---------|
| Todo tickets | N | TASK-008, TASK-009 |
| Completed tickets | N | TASK-001 through TASK-007 |
| Tracker | 1 | Reset to empty header |
| Active artifacts | N | TASK-008_manifest.json, ... |
| Archived artifacts | N | TASK-001/ through TASK-007/ |

### Needs Your Decision
| Category | Item | Action |
|----------|------|--------|
| Profile | `my-project.yaml` | Remove? (not _template or example) |
| Context | `python-agent/` | Remove submodule? |
| Context | `react-spa/` | Remove submodule? |

### Will Be Preserved
- Agent definitions in `.claude/agents/`
- Governance rules in `.claude/rules/`
- Specifications in `.claude/specs/`
- Slash commands in `.claude/commands/`
- `_template.yaml` and `example-polyglot.yaml` profiles
```

If there are no conditionally-clear items (no custom profiles, no context submodules), skip the interactive step and go straight to confirmation.

## Phase 3: Interactive Decisions

If Phase 2 found conditionally-clear items, present structured choices using the `AskUserQuestion` tool.

### 3.1 Profiles

For each non-template, non-example profile found:

```
AskUserQuestion:
  title: "Reset Workflow — Profile Decisions"
  questions:
    - id: "profile-<name>"
      prompt: "Profile: <name>.yaml — Remove from .claude/profiles/?"
      options:
        - id: "remove"
          label: "Remove — this is project-specific, not part of the template"
        - id: "keep"
          label: "Keep — this is a reusable reference profile"
```

### 3.2 Context Submodules

For each directory in `.claude/context/`:

```
AskUserQuestion:
  title: "Reset Workflow — Context Decisions"
  questions:
    - id: "context-<name>"
      prompt: "Context: .claude/context/<name>/ — Remove submodule?"
      options:
        - id: "remove"
          label: "Remove — this was added for a specific project"
        - id: "keep"
          label: "Keep — this is part of the template distribution"
```

## Phase 4: Confirm and Execute

### 4.1 Final Confirmation

After all interactive decisions are made, present the final action plan:

```
## Ready to Execute

**Clearing:**
- N ticket files (todo + completed)
- Ticket tracker (reset to empty)
- N artifact files
- N archived artifact directories
- [if chosen] Profile: <name>.yaml
- [if chosen] Context: .claude/context/<name>/

**Preserving:**
- All agents, rules, specs, commands
- Template and example profiles
- [if chosen] Profile: <name>.yaml
- [if chosen] Context: .claude/context/<name>/

Proceed? (yes/no)
```

Wait for explicit confirmation before proceeding.

### 4.2 Execute Clearing

Run the following operations in order:

**Step 1: Clear tickets**

```bash
rm -f .claude/features/todo/*.json .claude/features/todo/*.md
rm -f .claude/features/completed/*.json .claude/features/completed/*.md
```

**Step 2: Reset tracker**

Overwrite `.claude/features/ticket_tracker.md` with:

```markdown
# Ticket Tracker

| Ticket | Title | Status | Phase | Updated |
|--------|-------|--------|-------|---------|
```

**Step 3: Clear artifacts**

```bash
rm -f .claude/artifacts/*
rm -rf .claude/artifacts-archive/*
```

**Step 4: Remove selected profiles** (if any were marked for removal)

```bash
rm -f .claude/profiles/<name>.yaml
```

**Step 5: Remove selected context submodules** (if any were marked for removal)

```bash
git rm .claude/context/<name>
# If .gitmodules is now empty of submodule entries, clean it up
```

**Step 6: Ensure empty directories still exist**

```bash
mkdir -p .claude/features/todo
mkdir -p .claude/features/completed
mkdir -p .claude/artifacts
mkdir -p .claude/context
```

## Phase 5: Verify and Report

### 5.1 Verify Clean State

```bash
# Should all be empty
ls .claude/features/todo/
ls .claude/features/completed/
ls .claude/artifacts/
ls .claude/artifacts-archive/ 2>/dev/null
```

### 5.2 Present Summary

```
## Reset Complete

✅ Cleared N ticket files (N todo, N completed)
✅ Tracker reset to empty
✅ Cleared N artifact files
✅ Cleared N archived artifact directories
✅ [if applicable] Removed profile: <name>.yaml
✅ [if applicable] Removed context: .claude/context/<name>/

### Template State
| Directory | Status |
|-----------|--------|
| `.claude/features/todo/` | Empty ✅ |
| `.claude/features/completed/` | Empty ✅ |
| `.claude/features/ticket_tracker.md` | Reset ✅ |
| `.claude/artifacts/` | Empty ✅ |
| `.claude/artifacts-archive/` | Empty ✅ |
| `.claude/agents/` | N files (preserved) |
| `.claude/rules/` | N files (preserved) |
| `.claude/specs/` | N files (preserved) |
| `.claude/commands/` | N files (preserved) |
| `.claude/profiles/` | _template.yaml + N example(s) |

### Next Steps
- Commit the clean state: `git add -A && git commit -m "Reset workflow to clean template state"`
- Set up a new project: `/setup-project`
- Start planning features: `/new-task`
```

## Edge Cases

- **No tickets or artifacts exist:** Report "Already clean — nothing to reset" and exit.
- **Active git changes in ticket files:** Warn the user that uncommitted changes in `.claude/features/` will be lost. Suggest committing or stashing first.
- **Broken submodule state:** If `git rm` fails for a context submodule, report the error and suggest manual cleanup (`git submodule deinit`, edit `.gitmodules`).
- **Read-only files:** If deletion fails due to permissions, report which files couldn't be removed.
