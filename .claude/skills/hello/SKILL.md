<!-- AUTO-GENERATED from .claude/ — do not edit directly. Run: bash .claude/scripts/sync-claude.sh -->
---
name: hello
description: Start a new session with version check and orientation.
---
# Hello

Start a new session. Checks for framework updates, then orients you — either around a topic you provide or by scanning current work and suggesting where to go next.

## When to Use

- Starting a new session (the first thing you type)
- Returning to a project after a break
- Resuming a specific topic (`/hello I was working on the retry logic`)

## Initial Setup

1. Read the active profile from `.claude/profiles/*.yaml` (skip `_template.yaml`)
2. **Detect tracking mode:**

```bash
gh auth status 2>/dev/null
```

| Condition | Mode | Ticket source |
|-----------|------|---------------|
| `gh auth status` succeeds | **GitHub mode** | GitHub Issues via `gh` CLI |
| `gh` not installed or not authenticated | **Local mode** | `.claude/features/todo/TASK-NNN.json` files |

If the profile specifies `extensions.tracking.mode`, use that.

---

## Step 1: Version Check (Always)

Perform the same version check as `/check-update` Phases 1-3, but present the result as a compact one-liner rather than the full `/check-update` output.

### 1.1 Read Installed Version

Look for `.claude/.harness-version`:

```json
{
  "version": "0.1.0",
  "installed_at": "2026-02-25T10:30:00Z",
  "installed_from": "v0.1.0"
}
```

If the file does not exist, proceed to Step 1.2 — do not block the session start. The file will be auto-created after querying the latest release.

### 1.2 Query Latest Release

```bash
gh api repos/${CORE_FLOW_REPO:-damienstanton/harness-kit}/releases/latest --jq '.tag_name'
```

If `gh` fails, fall back to:

```bash
git ls-remote --tags --sort=-v:refname https://github.com/${CORE_FLOW_REPO:-damienstanton/harness-kit}.git 'v*' | head -1
```

If neither method returns a version, skip the comparison and note that no releases were found.

### 1.2a Auto-Create Version File (When Missing)

If Step 1.1 found no version file **and** Step 1.2 successfully retrieved a latest release tag, auto-create `.claude/.harness-version`:

1. Query the tag's commit SHA:

```bash
gh api repos/${CORE_FLOW_REPO:-damienstanton/harness-kit}/git/ref/tags/<tag> --jq '.object.sha'
```

If the SHA query fails, use `"unknown"` as the SHA value.

2. Write the version file:

```json
{
  "auto_detected": true,
  "installed_at": "<current ISO 8601 UTC timestamp>",
  "installed_from": {
    "ref": "<tag>",
    "sha": "<commit SHA or \"unknown\">"
  },
  "version": "<tag without leading v>"
}
```

The `auto_detected` field distinguishes this from installer-created files. The install scripts do not set this field.

3. Use the auto-created version as the installed version for comparison in Step 1.3.

If Step 1.2 also failed (no releases found), do NOT create the file — fall through to the "No releases found" output in Step 1.3.

### 1.3 Compare and Act

Strip any leading `v` prefix and compare semver strings.

| Condition | Action |
|-----------|--------|
| Up to date | Show: `harness-kit v0.2.0 (up to date)` |
| Update available | **Auto-upgrade** (see Step 1.4 below), then show: `harness-kit v0.1.0 → v0.2.0 (auto-upgraded)` |
| Ahead of latest | Show: `harness-kit v0.3.0-dev (ahead of latest release v0.2.0)` |
| Auto-detected (first run) | Show: `harness-kit v0.2.0 (auto-detected from latest release)` |
| No version file, no releases | Show: `harness-kit version unknown (no releases found to auto-detect)` |
| No releases found (has version) | Show: `harness-kit v0.1.0 (no releases found for comparison)` |

On the first run when the version file is auto-created, show the "auto-detected" line. On subsequent runs the file exists, so normal comparison logic applies.

### 1.4 Auto-Upgrade (When Update Available)

When Step 1.3 detects an update, prompt the user for confirmation before upgrading:

```
AskUserQuestion(
  title="harness-kit Update Available",
  questions=[{
    id: "auto-upgrade",
    prompt: "harness-kit v0.1.0 → v0.2.0 available. Upgrade now?",
    options: [
      {id: "upgrade", label: "Yes — install v0.2.0"},
      {id: "skip", label: "Skip — continue on v0.1.0"}
    ]
  }]
)
```

If **upgrade**: run the install script:

```bash
CORE_FLOW_REF=<latest_tag> bash <(gh api "repos/${CORE_FLOW_REPO:-damienstanton/harness-kit}/contents/.claude/scripts/install.sh?ref=<latest_tag>" -q '.content' | base64 --decode)
```

After the install completes, re-read `.claude/.harness-version` to confirm the upgrade succeeded. If the upgrade fails, show: `harness-kit v0.1.0 → v0.2.0 available (upgrade failed; run /check-update manually)`.

If **skip**: show `harness-kit v0.1.0 → v0.2.0 available (skipped; run /check-update to upgrade later)`.

Either way, continue to Step 2 — do not block the session.

---

## Step 2: Orientation

Branch based on whether the user provided arguments after `/hello`.

### Step 2a: Bare Invocation (`/hello`)

Scan current work and present a compact "what's on the plate" summary with one recommended next action.

#### Gather State

**GitHub mode:**

```bash
gh issue list --state open --json number,title,labels --limit 20
```

Partition issues by label:
- **In progress** — issues with `in-progress` label
- **Ready** — issues with `refined` label (and no `in-progress`)
- **Needs refinement** — open issues without `refined` label

**Local mode:**

Scan `.claude/features/todo/` for `.json` files. Partition by `"state"`:
- `"in-progress"` or `"blocked"` → active work
- `"refined"` → ready to start
- `"todo"` → needs refinement

**Git context (both modes):**

```bash
git branch --show-current
git status --short
git log --oneline -3
```

#### Present Orientation

```
👋 Session started.

harness-kit v0.2.0 (up to date)

What's on the plate:
  🔄 #42 Add rate limiting — in progress
  ⏸️  #43 Refactor error handling — refined, ready to start
  📋 #44 Add health check endpoint — needs refinement

Branch: 42-add-rate-limiting | 2 uncommitted files

Suggested: Continue #42 with `/resume-work`, or `/do-task 43` to start the next ready task.
```

**Adapt to project state:**

| State | Orientation |
|-------|-------------|
| No profile exists | "This project hasn't been set up yet. Run `/setup-project` to get started." |
| No tickets exist | "No open tasks. Use `/new-task` to plan your first feature." |
| All tickets done | "All N tasks completed. Use `/new-task` to plan new features, or `/review-code` for a health check." |
| In-progress work exists | Highlight the in-progress ticket and suggest `/resume-work` |
| Only refined tickets | Suggest `/do-task` on the highest-priority one |
| Uncommitted changes | Note them and suggest reviewing with `git diff` before proceeding |

### Step 2b: With Arguments (`/hello <context>`)

The user provides trailing text after `/hello` — a topic description, ticket number, branch name, or natural language about what they want to work on.

#### Match Context

Try these matchers in order, stopping at the first match:

**1. Ticket number** — if the context is or contains a number (e.g., `/hello 42` or `/hello #42`):

**GitHub mode:**
```bash
gh issue view <number> --json number,title,labels,state
```

**Local mode:** Read `.claude/features/todo/TASK-NNN.json`.

**2. Branch name** — if the context matches a local or remote branch:

```bash
git branch --list "*<context>*"
git branch -r --list "*<context>*"
```

If a branch matches, look for a linked issue (extract issue number from branch name pattern `<number>-*`).

**3. Fuzzy text match** — search open ticket titles and descriptions:

**GitHub mode:**
```bash
gh issue list --state open --json number,title,labels --limit 50
```

Scan titles for keyword overlap with the provided context. Rank by number of matching words.

**Local mode:** Read all `.json` files in `.claude/features/todo/` and match against `"title"` and `"description"` fields.

#### Present Match

If a ticket is matched:

```
👋 Session started.

harness-kit v0.2.0 (up to date)

Matched: #42 "Add rate limiting with token bucket algorithm"
  Status: in progress
  Branch: 42-add-rate-limiting
  Labels: task, refined, in-progress

Suggested: `/resume-work` to continue where you left off.
```

If a branch is matched but no linked ticket:

```
👋 Session started.

harness-kit v0.2.0 (up to date)

Matched branch: feat/retry-logic (no linked issue found)
  Last commit: 3 hours ago — "Add exponential backoff"
  Uncommitted: 1 file modified

Suggested: Continue working on this branch, or `/new-task` to create a tracking issue.
```

If no match is found, fall back to the bare invocation behavior (Step 2a) and note the unmatched context:

```
👋 Session started.

harness-kit v0.2.0 (up to date)

No matching ticket or branch found for "retry logic".

What's on the plate:
  🔄 #42 Add rate limiting — in progress
  ...
```

---

## Future Hooks

These extension points are planned but not yet implemented. They are documented here so future changes to `/hello` have a clear integration surface.

### Session Telemetry
Generate a trace ID at session start for REDACTED observability. Track session duration, commands invoked, and tickets touched. The trace structure follows the REDACTED spec: one trace per session, nested spans per command.

### External Context Pre-Load
Fetch external context at session start: CI pipeline status, pending PR reviews, team notifications, or Slack threads. This would surface relevant information before the user has to ask for it.

### Session History
Record session start/end events with metadata (user, project, tickets touched, commands run). Enable workflow analytics: average session length, common command sequences, time-to-completion per ticket type.

### Cross-Session Memory
Load relevant context from previous sessions: what was discussed, what decisions were made, what was left unfinished. This goes beyond `/resume-work` (which tracks ticket state) to capture conversational context.

---

## Notes

- `/hello` is intentionally lighter than `/status` — it presents one recommended action, not a full dashboard.
- `/hello` does not start any implementation work — it orients and suggests. The user decides what to do next.
- The version check is non-blocking: if the version file is missing or the release query fails, the session still starts normally.
- The `CORE_FLOW_REPO` environment variable (if set) overrides the default repo slug for the version check, same as `/check-update`.
