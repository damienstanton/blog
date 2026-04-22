<!-- AUTO-GENERATED from .claude/ — do not edit directly. Run: bash .claude/scripts/sync-claude.sh -->
---
name: refactor
description: Launch three refactor agents in parallel against a file or directory at function, module, and architecture scope.
---
# Refactor

Launch three refactor subagents in parallel against a user-specified file or directory. Each agent examines the code at a different scope: function-level, module-level, and architecture-level.

## Usage

```
/refactor src/http/retry.rs
/refactor src/components/
```

## Initial Setup

Read the active profile from `.claude/profiles/*.yaml` (skip `_template.yaml`) for language context.

## Step 1: Validate Target

Verify the target path exists. If it does not, report the error and stop.

```bash
ls <target-path>
```

## Step 2: Capture the Code

Read the target files to get the code for review. For a single file, read it directly. For a directory, read all source files within it (filtered by the project's primary language from the profile).

If a diff against the base branch is more appropriate (e.g., reviewing only changed code), detect the base branch:

```bash
BASE=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo "")
if [ -n "$BASE" ]; then
    git diff "$BASE" -- <target-path>
fi
```

If no diff is available (unchanged files or no base branch detected), read the files directly for a full review.

## Step 3: Launch All Three Subagents in Parallel

Invoke all three in a **single message** so they run concurrently. Each call uses the Task tool with `readonly: true`:

```
Task(subagent_type="refactor-small",  prompt="PROFILE: <profile-path>\n\nReview this code:\n{input}", readonly=true)
Task(subagent_type="refactor-medium", prompt="PROFILE: <profile-path>\n\nReview this code:\n{input}", readonly=true)
Task(subagent_type="refactor-large",  prompt="PROFILE: <profile-path>\n\nReview this code:\n{input}", readonly=true)
```

All agents are `readonly: true` — they cannot modify files. Only the implementing agent (or the user) applies fixes.

## Step 4: Collect and Unify Findings

After all three agents return, merge their outputs into a single unified report sorted by severity (Critical -> High -> Medium -> Low -> Info).

If all three agents return "LGTM," present a single clean summary:

> All three refactor agents reviewed the target and found no refactoring opportunities.

## Step 5: Present Findings Report

```
## Refactoring Opportunities

| # | Tier | Category | Severity | File | Lines | Description | Suggestion |
|---|------|----------|----------|------|-------|-------------|------------|
```

Tier values: `Function` (from refactor-small), `Module` (from refactor-medium), `Architecture` (from refactor-large).

## Step 6: Act on Findings

After presenting findings, ask the user which items to implement via **AskUserQuestion**. Group related findings when possible to avoid redundant changes.

```
AskUserQuestion(
  title="Refactoring — Select items to implement",
  questions=[{
    id: "refactor-selection",
    prompt: "Which refactoring items would you like to implement?",
    options: [
      {id: "all", label: "Implement all findings"},
      {id: "high", label: "Only High/Critical severity"},
      {id: "select", label: "I'll specify which ones"},
      {id: "none", label: "None — just informational"}
    ]
  }]
)
```

If the user chooses to implement, make the changes, then run the project's test and lint commands to verify nothing broke.
